-- =========================
-- CONFIG (edit these values)
-- Put this CONFIG at the top of the On-Startup block.
-- We also copy it to _G so On Tap / On Long-Press can access it.
-- =========================
local CONFIG = {
  LANG = "id",                     -- subtitle language code (e.g. "id", "en")
  FORMAT = "srt",                  -- subtitle format
  DOWNLOAD_DIR = "/sdcard/Download/",  -- where to save subtitles
  SOURCE = "all",                  -- wyzie source param
  ENCODING = nil,                  -- optional (&encoding=utf-8) or nil
  CURL_TIMEOUT = 30,               -- curl --max-time seconds
  SLEEP_LOG = 0.45,                -- pause between aniyomi.show_text calls
  OVERWRITE = true,                -- overwrite existing files
  DEBUG_SHOW_RESPONSE_SNIPPET = true
}

-- Expose CONFIG globally so other fields can read it
_G.CONFIG = CONFIG

-- ========== Startup logic & helpers ==========
local utils = require 'mp.utils'

local function sleep_secs(s)
  -- use sh sleep for a floating point friendly pause
  utils.subprocess({ args = {"sh", "-c", "sleep " .. tostring(s)}, cancellable = false })
end

local function log(msg)
  aniyomi.show_text(msg)
  sleep_secs(CONFIG.SLEEP_LOG)
end

local function encoding_param()
  if CONFIG.ENCODING and CONFIG.ENCODING ~= "" then
    return "&encoding=" .. CONFIG.ENCODING
  end
  return ""
end

local function ensure_dir()
  utils.subprocess({ args = {"sh", "-c", "mkdir -p '" .. CONFIG.DOWNLOAD_DIR .. "'"}, cancellable = false })
end

-- Robust media-title parsing (case-insensitive)
local function parse_title_for_imdb_season_episode(title)
  local upper = (title or ""):upper()
  local imdb = title:match("^(tt%d+)") or upper:match("TT%d+")
  if imdb then imdb = imdb:lower() end -- normalize to lowercase 'tt...'

  local season, episode
  local s, e = upper:match("S(%d+)%s*%-?%s*E(%d+)")
  if s and e then
    season, episode = s, e
  else
    s = upper:match("S(%d+)")
    if s then
      -- try to find episode after the S token
      local pos = upper:find("S" .. s, 1, true)
      if pos then
        local after = upper:sub(pos + #("S" .. s))
        local e2 = after:match("E(%d+)")
        if e2 then episode = e2 end
      end
      season = s
    end
    if not episode then
      -- fallback: first E anywhere
      local ep = upper:match("E(%d+)")
      if ep then episode = ep end
    end
  end

  return imdb, season, episode
end

local function build_wyzie_url(imdb, season, episode)
  local base = "https://sub.wyzie.ru/search?id=" .. imdb ..
               "&language=" .. CONFIG.LANG ..
               "&format=" .. CONFIG.FORMAT ..
               "&source=" .. CONFIG.SOURCE ..
               encoding_param()
  -- Append season & episode ONLY if a season token was detected (series)
  if season then
    if episode then
      base = base .. "&season=" .. season .. "&episode=" .. episode
    else
      base = base .. "&season=" .. season
    end
  end
  return base
end

-- ========== Main download routine (exposed globally) ==========
_G.downloadSubs = function()
  ensure_dir()

  -- Wait up to 90s for video to load (duration > 0)
  local waited = 0
  while true do
    local duration = mp.get_property_number("duration", 0)
    if duration and duration > 0 then break end
    waited = waited + 1
    if waited > 90 then
      log("⏱️ Timeout waiting for video to load (90s). Aborting.")
      return
    end
    log("⏱️ Waiting for video to load... (" .. waited .. "s)")
  end

  -- quick curl test to Wyzie to ensure curl works
  log("🔎 Testing curl and Wyzie connectivity...")
  local test_url = "https://sub.wyzie.ru/search?id=tt3659388&language=" .. CONFIG.LANG .. "&format=" .. CONFIG.FORMAT .. "&source=" .. CONFIG.SOURCE
  local test = utils.subprocess({
    capture_stdout = true,
    args = {"curl", "-s", "--max-time", tostring(math.max(5, CONFIG.CURL_TIMEOUT)), test_url},
    cancellable = false
  })
  if not test or test.status ~= 0 or not test.stdout then
    log("❌ Curl test failed. Make sure curl is installed and has network access.")
    return
  end
  log("✅ curl is available.")

  -- parse title
  local title = mp.get_property("media-title") or ""
  local imdb, season, episode = parse_title_for_imdb_season_episode(title)
  if not imdb then
    log("❌ Could not parse IMDb ID from media title: " .. (title ~= "" and title or "[empty]"))
    return
  end
  if season then
    log("🎬 Series detected. IMDb=" .. imdb .. " Season=" .. tostring(season) .. " Episode=" .. tostring(episode or "N/A"))
  else
    log("🎬 Movie detected. IMDb=" .. imdb)
  end

  -- Build and call Wyzie search
  local wyzie_url = build_wyzie_url(imdb, season, episode)
  log("🔍 Querying Wyzie: " .. wyzie_url)
  local res = utils.subprocess({
    capture_stdout = true,
    args = {"curl", "-s", "--max-time", tostring(CONFIG.CURL_TIMEOUT), wyzie_url},
    cancellable = false
  })
  if not res or res.status ~= 0 or not res.stdout then
    log("❌ Wyzie query failed (curl error).")
    return
  end

  -- parse JSON safely
  local ok, data = pcall(utils.parse_json, res.stdout)
  if not ok or not data or #data == 0 then
    log("❌ No subtitles found for the query.")
    if CONFIG.DEBUG_SHOW_RESPONSE_SNIPPET and res.stdout then
      local snippet = res.stdout:sub(1,200)
      log("🔎 API response snippet: " .. (snippet .. (res.stdout:len() > 200 and "..." or "")))
    end
    return
  end

  -- Filter and download matches (download all with matching language/format)
  local download_count = 0
  for _, entry in ipairs(data) do
    if entry and entry.url and (not entry.format or entry.format:lower() == CONFIG.FORMAT:lower()) then
      local fname = (entry.id and tostring(entry.id) or tostring(os.time())) .. "." .. CONFIG.FORMAT
      local outpath = CONFIG.DOWNLOAD_DIR .. fname

      if not CONFIG.OVERWRITE then
        local exists = utils.subprocess({ args = {"sh", "-c", "[ -f '" .. outpath .. "' ] && echo yes || echo no"}, capture_stdout = true })
        if exists and exists.stdout and exists.stdout:match("yes") then
          log("ℹ️ Skipping existing file: " .. outpath)
          goto continue_download_loop
        end
      end

      log("📥 Downloading: " .. (entry.display or entry.url))
      local dl_args = {"curl", "-s", "-L", "--max-time", tostring(CONFIG.CURL_TIMEOUT), "-o", outpath, entry.url}
      local dl_res = utils.subprocess({ args = dl_args, cancellable = false })
      if dl_res and dl_res.status == 0 then
        download_count = download_count + 1
        log("✅ Saved: " .. outpath)
      else
        log("⚠️ Download failed for: " .. (entry.url or "unknown"))
      end

      ::continue_download_loop::
    end
  end

  log("✅ Done. " .. tostring(download_count) .. " subtitle file(s) saved to " .. CONFIG.DOWNLOAD_DIR)
end

-- Run on startup only if this button is primary (Aniyomi placeholder)
if $isPrimary then
  _G.downloadSubs()
end
