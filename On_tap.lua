-- =========================
-- CONFIG (edit these values)
-- =========================
local CONFIG = {
  LANG = "id",                     -- subtitle language code (e.g. "id", "en")
  FORMAT = "srt",                  -- subtitle format
  DOWNLOAD_DIR = "/sdcard/1DMP/",  -- where to save subtitles
  SOURCE = "all",                  -- wyzie source param
  ENCODING = nil,                  -- optional (&encoding=utf-8) or nil
  CURL_TIMEOUT = 30,               -- curl --max-time seconds
  SLEEP_LOG = 0.45,                -- pause between aniyomi.show_text calls
  OVERWRITE = true,                -- overwrite existing files
  DEBUG_SHOW_RESPONSE_SNIPPET = true,
  TMDB_API_KEY = "PASTE HERE", -- TMDb API key
  TMDB_SEARCH_MAX = 3 -- take top 3 results
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
-- Returns: imdb (if any), season (string or nil), episode (string or nil)
local function parse_title_for_imdb_season_episode(title)
  local raw = title or ""
  local upper = raw:upper()
  local imdb = raw:match("^(tt%d+)") or upper:match("TT%d+")
  if imdb then imdb = imdb:lower() end -- normalize to lowercase 'tt...'

  local lower = raw:lower()

  local season, episode

  -- Try patterns that capture both season and episode first
  -- pattern order: most specific -> more general
  local s, e

  -- 1) "season 1 - episode 1" or "season 1 episode 1"
  s, e = lower:match("season%s*(%d+)%s*[-:]?%s*episode%s*(%d+)")
  if not s then
    -- 2) "s1 - e1", "s01 e01", "s1e1", "s01e01"
    s, e = lower:match("s%s*(%d+)%s*[-:]?%s*e%s*(%d+)")
  end
  if not s then
    s, e = lower:match("s(%d+)e(%d+)")
  end

  if s and e then
    season, episode = tostring(tonumber(s)), tostring(tonumber(e))
    return imdb, season, episode
  end

  -- If not both found, try season-only
  local s_only = lower:match("season%s*(%d+)") or lower:match("s%s*(%d+)")
  if s_only then
    season = tostring(tonumber(s_only))
  end

  -- Try episode-only patterns (many possible forms)
  local ep = lower:match("episode%s*(%d+)") or lower:match("ep%s*(%d+)") or lower:match("%s[eE]%s*(%d+)") or lower:match("e(%d+)")
  if ep then
    episode = tostring(tonumber(ep))
  end

  return imdb, season, episode
end

-- NEW: extract "Judul" from media-title more flexibly by removing common season/episode tokens
local function extract_title_from_media_title(raw_title)
  if not raw_title or raw_title == "" then return nil end

  local orig = raw_title
  local lower = orig:lower()

  -- helper to remove all occurrences of a pattern (pattern is a Lua pattern on the lowercased string)
  local function remove_pattern(pattern)
    local s, f = lower:find(pattern)
    while s do
      -- remove from orig using the same start/finish positions
      orig = orig:sub(1, s - 1) .. orig:sub(f + 1)
      lower = orig:lower()
      s, f = lower:find(pattern)
    end
  end

  -- Remove common season+episode patterns (both words and compact forms)
  remove_pattern("season%s*%d+%s*[-:]?%s*episode%s*%d+") -- "Season 1 - Episode 1" or "Season 1 Episode 1"
  remove_pattern("s%s*%d+%s*[-:]?%s*e%s*%d+")           -- "S1 - E1", "S01 E01"
  remove_pattern("s%d+e%d+")                            -- "S01E01" compact

  -- Remove remaining season-only / episode-only tokens
  remove_pattern("season%s*%d+")
  remove_pattern("episode%s*%d+")
  remove_pattern("ep%s*%d+")
  remove_pattern("%-?%s*[eE]%s*%d+") -- " - E01" or " E01" (best-effort; kept after other removals)

  -- Remove trailing marker words like "movie", "film"
  orig = orig:gsub("%s*%-?%s*[Mm]ovie%s*$", "")
  orig = orig:gsub("%s*%-?%s*[Ff]ilm%s*$", "")

  -- Trim surrounding separators and whitespace
  orig = orig:gsub("^%s*[%-%:]+%s*", ""):gsub("%s*[%-%:]+%s*$", "")
  orig = orig:gsub("^%s+", ""):gsub("%s+$", "")

  -- If there are still hyphen-separated parts, prefer the first meaningful segment
  local parts = {}
  for part in string.gmatch(orig, "([^%-]+)") do
    local p = part:gsub("^%s+", ""):gsub("%s+$", "")
    if p ~= "" then table.insert(parts, p) end
  end
  if #parts >= 1 then
    return parts[1]
  end

  -- Fallback: return trimmed original
  local title = orig:gsub("^%s+", ""):gsub("%s+$", "")
  if title == "" then return nil end
  return title
end

-- Helper: sanitize media string to safe filename
local function sanitize_filename(s)
  if not s then return "subtitle" end
  -- remove leading/trailing quotes and spaces
  s = s:gsub('^%s*"', ''):gsub('"%s*$', '')
  s = s:gsub('^%s*\'', ''):gsub('\'%s*$', '')
  -- replace any non-alphanumeric (and dot and dash) with underscore
  s = s:gsub("[^%w%.%-]+", "_")
  -- collapse multiple underscores
  s = s:gsub("_+", "_")
  -- trim underscores
  s = s:gsub("^_+", ""):gsub("_+$", "")
  if s == "" then s = "subtitle" end
  return s
end

-- NEW: Query TMDb search (multi) and return top N results (id + media_type)
local function tmdb_search_top(title)
  if not title or title == "" then return {} end
  local key = CONFIG.TMDB_API_KEY
  -- use curl --get and --data-urlencode for query safe encoding
  local url = "https://api.themoviedb.org/3/search/multi?api_key=" .. key .. "&language=en-US&page=1&include_adult=false"
  local args = {"curl", "-s", "--get", "--data-urlencode", "query=" .. title, url, "--max-time", tostring(CONFIG.CURL_TIMEOUT)}
  local res = utils.subprocess({ capture_stdout = true, args = args, cancellable = false })
  if not res or res.status ~= 0 or not res.stdout then
    log("⚠️ TMDb search failed for title: " .. title)
    return {}
  end
  local ok, parsed = pcall(utils.parse_json, res.stdout)
  if not ok or not parsed or not parsed.results then
    log("⚠️ TMDb returned no results for: " .. title)
    return {}
  end
  local results = {}
  for i, item in ipairs(parsed.results) do
    if i > CONFIG.TMDB_SEARCH_MAX then break end
    if item and item.id and item.media_type then
      table.insert(results, {id = item.id, media_type = item.media_type})
    end
  end
  return results
end

-- NEW: Given tmdb id + media_type, fetch external_ids to obtain imdb_id
local function tmdb_get_imdb_id(tmdb_id, media_type)
  if not tmdb_id or not media_type then return nil end
  local key = CONFIG.TMDB_API_KEY
  local base
  if media_type == "movie" then
    base = "https://api.themoviedb.org/3/movie/" .. tostring(tmdb_id) .. "/external_ids?api_key=" .. key
  elseif media_type == "tv" then
    base = "https://api.themoviedb.org/3/tv/" .. tostring(tmdb_id) .. "/external_ids?api_key=" .. key
  else
    -- skip other media types
    return nil
  end
  local res = utils.subprocess({ capture_stdout = true, args = {"curl", "-s", "--max-time", tostring(CONFIG.CURL_TIMEOUT), base}, cancellable = false })
  if not res or res.status ~= 0 or not res.stdout then
    return nil
  end
  local ok, parsed = pcall(utils.parse_json, res.stdout)
  if not ok or not parsed then return nil end
  if parsed.imdb_id and parsed.imdb_id ~= "" then
    return parsed.imdb_id
  end
  return nil
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
    log("ℹ️ IMDb not directly found in media-title. Will attempt TMDb search by extracted title.")
  end

  if season then
    log("🎬 Series detected. Season=" .. tostring(season) .. " Episode=" .. tostring(episode or "N/A"))
  else
    log("🎬 Movie or single detected.")
  end

  -- Collect imdb_ids to query Wyzie: either the one parsed or those resolved via TMDb
  local imdb_ids = {}

  if imdb then
    table.insert(imdb_ids, imdb)
  else
    -- Extract title portion from media-title
    local search_title = extract_title_from_media_title(title)
    if not search_title then
      log("❌ Could not extract title from media-title: " .. (title ~= "" and title or "[empty]"))
      return
    end
    log("🔎 Searching TMDb for title: " .. search_title)
    local tmdb_results = tmdb_search_top(search_title)
    if not tmdb_results or #tmdb_results == 0 then
      log("❌ No TMDb results found for: " .. search_title)
      return
    end
    -- For each TMDb result (up to top N), fetch imdb id
    for _, r in ipairs(tmdb_results) do
      log("ℹ️ TMDb candidate: id=" .. tostring(r.id) .. " type=" .. tostring(r.media_type))
      local got = tmdb_get_imdb_id(r.id, r.media_type)
      if got then
        log("✅ Resolved IMDB: " .. got)
        -- normalize to lowercase tt...
        got = tostring(got)
        if got:sub(1,2):lower() ~= "tt" then
          got = "tt" .. got
        end
        table.insert(imdb_ids, got:lower())
      else
        log("⚠️ No IMDB id for TMDb id=" .. tostring(r.id))
      end
    end
    if #imdb_ids == 0 then
      log("❌ Tidak ada IMDB id yang dapat di-resolve dari TMDb hasil pencarian.")
      return
    end
  end

  -- Remove duplicates in imdb_ids
  local unique = {}
  local uniq_list = {}
  for _, v in ipairs(imdb_ids) do
    if v and v ~= "" and not unique[v] then
      unique[v] = true
      table.insert(uniq_list, v)
    end
  end

  -- For each imdb_id found, query Wyzie and download subtitles
  local total_download_count = 0
  for _, imdb_id in ipairs(uniq_list) do
    log("🔍 Querying Wyzie for IMDb: " .. imdb_id)
    local wyzie_url = build_wyzie_url(imdb_id, season, episode)
    log("🔍 Wyzie URL: " .. wyzie_url)
    local res = utils.subprocess({
      capture_stdout = true,
      args = {"curl", "-s", "--max-time", tostring(CONFIG.CURL_TIMEOUT), wyzie_url},
      cancellable = false
    })
    if not res or res.status ~= 0 or not res.stdout then
      log("❌ Wyzie query failed (curl error) for " .. imdb_id)
    else
      -- parse JSON safely
      local ok, data = pcall(utils.parse_json, res.stdout)
      if not ok or not data or #data == 0 then
        log("❌ No subtitles found for the query imdb=" .. imdb_id)
        if CONFIG.DEBUG_SHOW_RESPONSE_SNIPPET and res.stdout then
          local snippet = res.stdout:sub(1,200)
          log("🔎 API response snippet: " .. (snippet .. (res.stdout:len() > 200 and "..." or "")))
        end
      else
        -- Filter and download matches (download all with matching language/format)
        local download_count = 0
        for _, entry in ipairs(data) do
          if entry and entry.url and (not entry.format or entry.format:lower() == CONFIG.FORMAT:lower()) then
            -- name file from entry.media (sanitized) and entry.id to ensure uniqueness
            local media_name = entry.media or entry.display or ("id_" .. tostring(entry.id or os.time()))
            local safe_name = sanitize_filename(media_name)
            local fname = safe_name .. "_" .. (entry.id and tostring(entry.id) or tostring(os.time())) .. "." .. CONFIG.FORMAT
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
              total_download_count = total_download_count + 1
              log("✅ Saved: " .. outpath)
            else
              log("⚠️ Download failed for: " .. (entry.url or "unknown"))
            end

            ::continue_download_loop::
          end
        end
        log("✅ Done for imdb=" .. imdb_id .. ". " .. tostring(download_count) .. " subtitle file(s) saved to " .. CONFIG.DOWNLOAD_DIR)
      end
    end
  end

  log("✅ All done. Total saved: " .. tostring(total_download_count) .. " subtitle file(s) to " .. CONFIG.DOWNLOAD_DIR)
end

-- Run on startup only if this button is primary (Aniyomi placeholder)
if $isPrimary then
  _G.downloadSubs()
end
