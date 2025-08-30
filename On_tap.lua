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
  TMDB_API_KEY = "PASTE HERE",     -- TMDb API key
  TMDB_SEARCH_MAX = 3,             -- take top 3 results
  MAX_SUBTITLES_PER_IMDB = 5       -- Max number of subtitles to download per IMDb ID
}

-- Expose CONFIG globally so other fields can read it
_G.CONFIG = CONFIG

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
        for i, entry in ipairs(data) do
          -- Stop downloading if the max limit is reached
          if download_count >= CONFIG.MAX_SUBTITLES_PER_IMDB then
            log("⚠️ Reached the max subtitle limit for IMDb ID: " .. imdb_id)
            break
          end

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
