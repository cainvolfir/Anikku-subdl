-- On Long-Press: delete all files of CONFIG.FORMAT in CONFIG.DOWNLOAD_DIR
local utils = require 'mp.utils'
local cfg = (_G and _G.CONFIG) or {
  DOWNLOAD_DIR = "/sdcard/1DMP/",
  FORMAT = "srt"
}

local dir = cfg.DOWNLOAD_DIR
local fmt = cfg.FORMAT or "srt"

local find_cmd = "find '" .. dir .. "' -maxdepth 1 -type f -name '*." .. fmt .. "' -print"
local res = utils.subprocess({ capture_stdout = true, args = {"sh", "-c", find_cmd}, cancellable = false })

local deleted = 0
if res and res.stdout and res.stdout ~= "" then
  for path in res.stdout:gmatch("[^\r\n]+") do
    utils.subprocess({ args = {"rm", "-f", path}, cancellable = false })
    deleted = deleted + 1
  end
end

aniyomi.show_text("🗑️ Deleted " .. tostring(deleted) .. " ." .. fmt .. " file(s) from " .. dir)
