
# Aniyomi — Wyzie Subtitle Downloader Button

**A customizable Aniyomi custom-button that automatically searches and downloads subtitles (SRT or other formats) from a Wyzie subtitle API using `curl` (Termux-friendly).**

> **Files in this repo** (paste the matching block into Aniyomi's Custom Button fields):
- [On_tap.lua](./On_tap.lua) — paste into Aniyomi → Custom Button → **Lua code**. Contains the `CONFIG` block and the main download routine (this is where you change language, download dir, etc.).
- [On_long.lua](./On_long.lua) — paste into **Lua code (on long-press)** (deletes the downloaded `.srt` files).

---

## Quick install & usage (step-by-step)

1. **Install [Termux](https://f-droid.org/en/packages/com.termux/)** 

3. **Open Termux** and update packages & install `curl`:
   ```bash
   pkg update && pkg upgrade -y
   pkg install curl -y
   ```
3. Grant all file access for aniyomi in your android setting
5. Open **Aniyomi → Settings → Player → Custom Buttons → Add custom button**.

6. Copy-paste the code from the repo into the matching Custom Button fields:

   * **On tap**: copy the contents of [On\_tap.lua](./On_tap.lua). This file contains the `CONFIG` table at the top — edit it there (language, download folder, source, etc.). **MAKE SURE TO PUT YOUR TMDB API KEY IN CONFIG SETUP** You can get it just by Sign Up/Login on TMDB site. Also note the script assigns `_G.CONFIG` so other fields can read it.
   * **On Long-Press**: copy the contents of [On\_long.lua](./On_long.lua).

9. Open any episode or movie **wait for the video to load** then tap the custom button. The script code routine will:

   * Detect the entry title (and season/episode for series) from the entry, and grab its IMDB ID (The long algorithm is grab the entry title, find its TMDb ID using TMDb API key then use the founded TMDb ID to find its IMDb ID since searching the subtitle by Wyzie API is more accurate using IMDB ID)
   * Query the Wyzie API using your `CONFIG` options (`language`, `format`, `source`, `encoding`),
   * Download **all** matching subtitles to the configured folder (default: `/sdcard/1DMP/`).

10. Load a downloaded subtitle in Aniyomi by choosing **Add external subtitle** and pointing to the downloaded `.srt` file.
    
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

## Troubleshooting

* **“Curl test failed”** — ensure `curl` is installed in Termux and network access is working. Test in Termux: `curl https://sub.wyzie.ru`.
* **No subtitles found but you know they exist** — open `On_startup.lua` and set `SOURCE = "all"` (and try `ENCODING = "utf-8"` if needed). If `DEBUG_SHOW_RESPONSE_SNIPPET = true`, the script will show an API response snippet to help debug.


## Files & licensing

This repo contains:

* `On_startup.lua` — main script + `CONFIG`
* `On_tap.lua` — manual trigger
* `On_long.lua` — delete downloaded subtitles
* `README.md`, `LICENSE` (MIT), `.gitignore`

**License:** MIT (see `LICENSE` file)

---

## Credits & disclaimers

* **Authorship:** The code in this repository was generated/assisted by an AI. Use at your own risk — test before relying on it for important tasks.
* This project queries the Wyzie subtitle API and downloads files via `curl`. Wyzie is not affiliated with this repo.

---

## Useful links

* Termux (F-Droid): `https://f-droid.org/en/packages/com.termux/`
