-- On Tap: call the same download routine defined on startup
if _G and _G.downloadSubs then
  _G.downloadSubs()
else
  aniyomi.show_text("⚠️ Download function not available. Try restarting playback.")
end
