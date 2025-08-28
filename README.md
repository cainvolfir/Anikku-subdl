
# Anikku — Wyzie Subtitle Downloader Button

**A customizable Anikku custom-player button that automatically searches and downloads subtitles (SRT or other formats) from a Wyzie subtitle API using `curl` (Termux-friendly).**

> **Target:** Anikku (an Aniyomi fork that have feature editing entry info).  
> **Files in this repo** (paste the matching block into Anikku's Custom Button fields):
- [On_startup.lua](./On_startup.lua) — **(required)** paste into Anikku → Custom Button → **On Startup**. Contains the `CONFIG` block and the main download routine (this is where you change language, download dir, etc.).
- [On_tap.lua](./On_tap.lua) — paste into **On Tap** (manual re-run fallback).
- [On_long.lua](./On_long.lua) — paste into **On Long-Press** (deletes downloaded `.srt` files).
- [imdb_id.user.js](./imdb_id.user.js) — optional userscript to help copy IMDb IDs from IMDb pages (save as `.user.js` and install in Tampermonkey/Violentmonkey).

---

## Quick install & usage (step-by-step)

1. **Install [Termux](https://f-droid.org/en/packages/com.termux/)** 

3. **Open Termux** and update packages & install `curl`:
   ```bash
   pkg update && pkg upgrade -y
   pkg install curl -y
   ```
4. **Install [Anikku](https://github.com/komikku-app/anikku)**
5. Open **Anikku → Settings → Player → Custom Buttons → Add custom button**.

6. Copy-paste the code from the repo into the matching Custom Button fields:

   * **On Startup**: copy the contents of [On\_startup.lua](./On_startup.lua). This file contains the `CONFIG` table at the top — edit it there (language, download folder, source, etc.). Also note the script assigns `_G.CONFIG` so other fields can read it.
   * **On Tap**: copy the contents of [On\_tap.lua](./On_tap.lua).
   * **On Long-Press**: copy the contents of [On\_long.lua](./On_long.lua).
     Save the button and mark it **primary** if you want the On Startup script to run automatically when you open a video.

7. Add entry to your Anikku library (movie or series) and open the entry.

8. **Edit the entry to include the IMDb ID**:

   * Open the entry → tap the overflow menu (three dots, top-right) → **Edit info** → paste the IMDb ID into the title field → **Save**.
> Make sure there's "S1 - E1" or something similar like that in your episode name. This will affect media-title.
     Tip: use the included [imdb\_id.user.js](./imdb_id.user.js) userscript to copy IMDb IDs quickly from IMDb pages (save as `imdb_id.user.js` and install in Tampermonkey/Violentmonkey).

9. Open any episode or movie and **wait for the video to load** (the script waits up to 90 seconds). The On Startup routine will:

   * Detect the IMDb ID (and season/episode for series) from the entry,
   * Query the Wyzie API using your `CONFIG` options (`language`, `format`, `source`, `encoding`),
   * Download **all** matching subtitles to the configured folder (default: `/sdcard/1DMP/`).

10. Load a downloaded subtitle in Anikku by choosing **Add external subtitle** and pointing to the downloaded `.srt` file.

11. If the On Startup routine didn’t run (rare), **tap** the custom button — On Tap is a manual fallback and will re-run the same routine.

12. **Long-press** the button to delete all `.srt` files from the download directory (the script will tell you how many files were deleted). This is useful to free storage quickly.

---

## Suggested workflow (recommended)

1. Let the script download all available subtitles.
2. Load one downloaded `.srt` file and check timing/translation.
3. If a subtitle matches perfectly, **long-press** the button to clear the download folder — the already loaded subtitle will remain active in the player’s memory even if the file is removed from disk.

---

## Configuration

* All options are in the `CONFIG` table at the top of **On\_startup.lua**:

  * `LANG` — language code (e.g. `"id"` for Indonesian, `"en"` for English)
  * `FORMAT` — subtitle format (default `"srt"`)
  * `DOWNLOAD_DIR` — where to save subtitles (default `"/sdcard/Download/"`)
  * `SOURCE` — Wyzie `source` query (use `"all"` to aggregate)
  * `ENCODING` — optional (e.g. `"utf-8"`)
  * `CURL_TIMEOUT`, `SLEEP_LOG`, `OVERWRITE`, `DEBUG_SHOW_RESPONSE_SNIPPET`
* Edit the `CONFIG` block in **On\_startup.lua** and restart playback so `_G.CONFIG` is set for On Tap / On Long-Press.

---

## Userscript

* The repo includes `imdb_id.user.js` — save it with the `.user.js` extension and open in a userscript manager like **Tampermonkey** or **Violentmonkey**. The userscript adds an easy copy button to IMDb pages to extract the `tt...` ID.
* Userscripts generally use `.user.js` so browsers/userscript managers can install them directly.

---

## Troubleshooting

* **“Curl test failed”** — ensure `curl` is installed in Termux and network access is working. Test in Termux: `curl https://sub.wyzie.ru`.
* **No subtitles found but you know they exist** — open `On_startup.lua` and set `SOURCE = "all"` (and try `ENCODING = "utf-8"` if needed). If `DEBUG_SHOW_RESPONSE_SNIPPET = true`, the script will show an API response snippet to help debug.
* **Title parsing fails** — verify the Anikku entry’s media title contains a valid IMDb ID (e.g. `tt1234567`). You can paste the IMDb ID in Edit Info manually or use the userscript to copy it.

---

## Files & licensing

This repo contains:

* `On_startup.lua` — main script + `CONFIG`
* `On_tap.lua` — manual trigger
* `On_long.lua` — delete downloaded subtitles
* `imdb_id.user.js` — userscript helper
* `README.md`, `LICENSE` (MIT), `.gitignore`

**License:** MIT (see `LICENSE` file)

---

## Credits & disclaimers

* **Authorship:** The code in this repository was generated/assisted by an AI. Use at your own risk — test before relying on it for important tasks.
* This project queries the Wyzie subtitle API and downloads files via `curl`. Wyzie is not affiliated with this repo.

---

## Useful links

* Termux (F-Droid): `https://f-droid.org/en/packages/com.termux/`
* Anikku (example source): `https://github.com/komikku-app/anikku`
* Tampermonkey (userscript manager): `https://www.tampermonkey.net/`
