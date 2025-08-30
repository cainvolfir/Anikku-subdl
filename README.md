# Aniyomi — Wyzie Subtitle Downloader Button

A simple **Aniyomi custom button** (Lua) that automatically searches and downloads subtitles (SRT or other formats) from the Wyzie subtitle API using `curl`. Termux-friendly.

---

## What this custom-button does

Tap the custom button while playing an episode or movie in Aniyomi: the script finds the title → looks up its IMDB ID via TMDb → queries Wyzie for matching subtitles → downloads them to your chosen folder.

---

## Files in this repo

* `On_tap.lua` — **Main script**. Paste into Aniyomi → Custom Button → Lua code. Edit the `CONFIG` block at the top to set language, download folder, TMDb API key, etc.
* `On_long.lua` — Paste into the Lua Code (long-press) field. Function: Deletes downloaded subtitle files from the download folder.
* `README.md`, `LICENSE` (MIT), `.gitignore`

---

## Quick install & usage (concise step-by-step)

1. Install \[Termux]\([https://f-droid.org/en/packages/com.termux/](https://f-droid.org/en/packages/com.termux/)) (F‑Droid link).

2. Open Termux and update packages, then install `curl`:

```bash
pkg update && pkg upgrade -y
pkg install curl -y
```

3. In Android settings grant Aniyomi full file access (Setting → Permission → Storage access/Manage all files) so the script can save subtitle files to your chosen folder.

4. Open Aniyomi → **Settings → Player → Custom Buttons** → **Add custom button**.

5. Copy-paste code from this repo into the matching fields:

   * **On tap**: paste `On_tap.lua`. Edit the `CONFIG` section at the top (language, download dir, TMDb API key, etc.) as you need.
   * **On long-press**: paste `On_long.lua`.

6. Open any episode or movie and wait for the video to load. Tap the custom button:

   * The script detects the title with season and episode (if any), finds the TMDb ID (using your TMDb API key), converts that to an IMDb ID, then queries Wyzie and downloads matching subtitles.

7. In Aniyomi, add the downloaded `.srt` as an external subtitle (Player → Add external subtitle) and pick the file from your download folder.

8. Long-press the button to remove subtitle files from the download directory (the loaded subtitle stays active in memory).

---

## Suggested workflow (recommended)

1. Tap to download all available subtitles for the current entry.
2. Load some `.srt` and check the subtitle timing/translation.
3. If it's already matches, long-press to clear the download folder and free space — the currently loaded subtitle remains in the player.

---

## Configuration (`CONFIG` table)

Edit the `CONFIG` table at the top of `On_tap.lua`. Important keys:

* `LANG` — language code (e.g. `"id"` for Indonesian, `"en"` for English).
* `FORMAT` — subtitle format (default: `"srt"`).
* `DOWNLOAD_DIR` — save location (example: `"/sdcard/Download/"`).
* `SOURCE` — Wyzie `source` query (use `"all"` to aggregate sources).
* `ENCODING` — optional (e.g. `"utf-8"`).
* `CURL_TIMEOUT`, `SLEEP_LOG`, `OVERWRITE`, `DEBUG_SHOW_RESPONSE_SNIPPET` — advanced/debug options.
* **TMDB\_API\_KEY** — *required* for title→TMDb→IMDb lookup. Get a key by signing up on TMDb and copying your API key into the `CONFIG` table.

---

## How to get a TMDb API key
1. Go to [TMDb](https://themoviedb.org)
2. Sign Up/Login
3. Find the API section in your settings.
4. Click Request API Key.
5. Copy your key and paste it in TMDB_API_KEY.

---

## Why use IMDb ID instead of TMDb? 🎥
The script uses IMDb ID because IMDb is very well-known everywhere, much wider than TMDb. Even though Wyzie API support using TMDb ID but there's some movie/shows that doesn't get recognized by Wyzie API despite the correct TMDb ID. That's why IMDb ID is better to use.

---

## Troubleshooting (quick fixes)

* **"Curl test failed"** — make sure `curl` is installed in Termux and the device has network access. Test: `curl https://sub.wyzie.ru` in Termux.
* **No subtitles found** but you expect some:

  * Try `SOURCE = "all"` in the `CONFIG` table.
  * If subtitle characters look wrong, try `ENCODING = "utf-8"`.
  * Set `DEBUG_SHOW_RESPONSE_SNIPPET = true` to view a short API response for debugging.
* **Permissions errors** — ensure Aniyomi has storage permission and Termux has network access.

If none of the above helps, open `On_tap.lua`, enable debug, and copy the response snippet to an issue or message for help.

---

## Security & disclaimers

* Use this script at your own risk. Test carefully before relying on it.
* The repo queries the Wyzie subtitle API; Wyzie is not affiliated with this project.
* The code was generated/assisted by an AI; double-check behavior before wide use.

---

## License

MIT — see `LICENSE` file.

---

## Useful links

* Termux (F‑Droid): [https://f-droid.org/en/packages/com.termux/](https://f-droid.org/en/packages/com.termux/)
* TMDb: [https://www.themoviedb.org/](https://www.themoviedb.org/)

---

## Need changes?

If you want the README shortened further, translated, or adjusted to match specific wording in the Lua files (e.g., exact `CONFIG` keys), tell me which flavor you want and I’ll update it.
