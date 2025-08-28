// ==UserScript==
// @name        IMDb ID Modal (Debug & Fixed)
// @namespace   http://tampermonkey.net/
// @version     1.3
// @description Modal centered + blur; debug logs + clear old closed-flag so modal can reappear. SPA-safe.
// @match       https://www.imdb.com/title/tt*
// @match       https://m.imdb.com/title/tt*
// @grant       none
// @run-at      document-idle
// ==/UserScript==

(function () {
  'use strict';

  const STORAGE_KEY = 'imdb_modal_closed_v1';
  const OVERLAY_ID = 'imdb-id-modal-overlay-v1';

  console.log('[IMDbModal] script loaded');

  // --- Utilities ---
  const imdbIdFromPath = () => {
    const m = window.location.pathname.match(/\/title\/(tt\d+)/);
    return m ? m[1] : null;
  };

  async function safeCopy(text) {
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        await navigator.clipboard.writeText(text);
        return true;
      }
    } catch (e) { /* fallthrough */ }
    try {
      const ta = document.createElement('textarea');
      ta.value = text;
      ta.style.position = 'fixed';
      ta.style.left = '-9999px';
      document.body.appendChild(ta);
      ta.select();
      const ok = document.execCommand('copy');
      document.body.removeChild(ta);
      return !!ok;
    } catch (e) {
      console.error('[IMDbModal] safeCopy fallback failed', e);
      return false;
    }
  }

  function removeExisting() {
    const e = document.getElementById(OVERLAY_ID);
    if (e) {
      console.log('[IMDbModal] removing existing overlay');
      e.remove();
    }
  }

  function shouldShowModal() {
    return !sessionStorage.getItem(STORAGE_KEY);
  }

  function markModalClosed() {
    try { sessionStorage.setItem(STORAGE_KEY, '1'); }
    catch (e) { console.warn('[IMDbModal] cannot set sessionStorage', e); }
  }

  // If old flag exists, remove it (so popup will appear again).
  if (sessionStorage.getItem(STORAGE_KEY)) {
    console.log('[IMDbModal] found old closed flag in sessionStorage -> removing so modal can reappear');
    try { sessionStorage.removeItem(STORAGE_KEY); } catch (e) { console.warn('[IMDbModal] removeItem failed', e); }
  }

  function showModal(imdbID) {
    if (!imdbID) { console.warn('[IMDbModal] showModal called without imdbID'); return; }
    if (!shouldShowModal()) { console.log('[IMDbModal] user closed modal earlier this session, skipping show'); return; }

    // Avoid duplicate
    if (document.getElementById(OVERLAY_ID)) {
      console.log('[IMDbModal] overlay already present, aborting showModal');
      return;
    }

    console.log('[IMDbModal] showModal for', imdbID);

    // overlay
    const overlay = document.createElement('div');
    overlay.id = OVERLAY_ID;
    Object.assign(overlay.style, {
      position: 'fixed', inset: '0',
      display: 'flex', alignItems: 'center', justifyContent: 'center',
      backgroundColor: 'rgba(0,0,0,0.45)', zIndex: 2147483647,
      backdropFilter: 'blur(6px)', WebkitBackdropFilter: 'blur(6px)', pointerEvents: 'auto',
    });

    // modal
    const modal = document.createElement('div');
    Object.assign(modal.style, {
      width: 'min(560px, 92%)',
      background: 'linear-gradient(180deg, #0f0f10, #151515)',
      color: '#fff', borderRadius: '14px', boxShadow: '0 14px 40px rgba(0,0,0,0.6)',
      padding: '22px', fontFamily: '"Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif',
      textAlign: 'center', position: 'relative',
    });

    // header badge + title
    const header = document.createElement('div');
    header.style.display = 'flex'; header.style.alignItems = 'center'; header.style.justifyContent = 'center'; header.style.gap = '12px';
    const badge = document.createElement('div');
    badge.textContent = 'IMDb';
    Object.assign(badge.style, { backgroundColor: '#F5C518', color: '#000', fontWeight: '800', padding: '7px 12px', borderRadius: '8px', letterSpacing: '1px', fontSize: '14px' });
    const title = document.createElement('div');
    title.textContent = 'Copy IMDb ID';
    Object.assign(title.style, { fontSize: '20px', fontWeight: '700', color: '#f5f5f5' });
    header.appendChild(badge); header.appendChild(title);

    // body: subtitle + id box
    const body = document.createElement('div'); body.style.marginTop = '16px';
    const subtitle = document.createElement('div'); subtitle.textContent = 'ID film / serial saat ini:'; subtitle.style.fontSize = '13px'; subtitle.style.opacity = '0.95';
    const idBox = document.createElement('div'); idBox.textContent = imdbID;
    Object.assign(idBox.style, { marginTop: '12px', padding: '14px 16px', backgroundColor: '#0b0b0b', borderRadius: '10px', fontSize: '20px', letterSpacing: '1px', fontWeight: '700', display: 'inline-block', color: '#F5C518', boxShadow: 'inset 0 -2px 0 rgba(0,0,0,0.35)' });

    // buttons
    const row = document.createElement('div'); Object.assign(row.style, { display: 'flex', gap: '12px', justifyContent: 'center', marginTop: '20px', flexWrap: 'wrap' });
    const copyBtn = document.createElement('button'); copyBtn.innerHTML = 'Salin IMDb ID';
    Object.assign(copyBtn.style, { backgroundColor: '#F5C518', color: '#000', border: 'none', padding: '12px 20px', borderRadius: '10px', fontWeight: '800', cursor: 'pointer', fontSize: '15px', boxShadow: '0 10px 24px rgba(245,197,24,0.16)' });
    const closeBtn = document.createElement('button'); closeBtn.innerHTML = 'Tutup';
    Object.assign(closeBtn.style, { backgroundColor: 'transparent', color: '#ddd', border: '1px solid rgba(255,255,255,0.06)', padding: '10px 16px', borderRadius: '10px', cursor: 'pointer', fontSize: '14px' });

    const hint = document.createElement('div'); hint.textContent = 'ID juga diambil otomatis dari URL halaman.'; Object.assign(hint.style, { marginTop: '12px', fontSize: '13px', color: '#bbb', opacity: '0.98' });

    // top-right X
    const x = document.createElement('button'); x.innerHTML = '&times;';
    Object.assign(x.style, { position: 'absolute', top: '12px', right: '12px', background: 'transparent', color: '#bbb', border: 'none', fontSize: '22px', cursor: 'pointer', lineHeight: '1' });

    // assemble
    body.appendChild(subtitle); body.appendChild(idBox);
    row.appendChild(copyBtn); row.appendChild(closeBtn);
    body.appendChild(row); body.appendChild(hint);
    modal.appendChild(x); modal.appendChild(header); modal.appendChild(body);
    overlay.appendChild(modal); document.body.appendChild(overlay);

    // accessibility: focus
    copyBtn.focus();

    // events
    copyBtn.addEventListener('click', async () => {
      console.log('[IMDbModal] copy button clicked');
      const ok = await safeCopy(imdbID);
      const original = copyBtn.innerHTML;
      copyBtn.innerHTML = ok ? 'Tersalin!' : 'Gagal';
      setTimeout(() => (copyBtn.innerHTML = original), 1400);
    });

    function doClose() {
      console.log('[IMDbModal] modal closed by user');
      markModalClosed();
      overlay.remove();
    }
    closeBtn.addEventListener('click', doClose);
    x.addEventListener('click', doClose);
    overlay.addEventListener('mousedown', (ev) => { if (ev.target === overlay) doClose(); });

    // safety: if site removes the overlay (rare), we won't auto recreate (respect user)
    console.log('[IMDbModal] modal appended to DOM');
  }

  // ensure modal shows (with debug)
  function ensureModal() {
    try {
      const id = imdbIdFromPath();
      console.log('[IMDbModal] ensureModal called, id=', id, 'overlayExists=', !!document.getElementById(OVERLAY_ID), 'shouldShow=', shouldShowModal());
      if (!id) return;
      if (!shouldShowModal()) {
        console.log('[IMDbModal] user closed modal earlier this session; skipping');
        return;
      }
      if (!document.getElementById(OVERLAY_ID)) showModal(id);
    } catch (e) {
      console.error('[IMDbModal] ensureModal error', e);
    }
  }

  // Start triggers: DOMContentLoaded, fallback timeout, and immediate attempt
  if (document.readyState === 'complete' || document.readyState === 'interactive') {
    setTimeout(ensureModal, 200);
  } else {
    window.addEventListener('DOMContentLoaded', () => { setTimeout(ensureModal, 200); });
  }
  // extra fallback after a bit (for SPA heavy pages)
  setTimeout(ensureModal, 800);

  // SPA handling: intercept push/replace/pop and poll
  let lastPath = location.pathname + location.search + location.hash;
  function checkUrlChange() {
    const now = location.pathname + location.search + location.hash;
    if (now !== lastPath) {
      console.log('[IMDbModal] URL change detected', lastPath, '->', now);
      lastPath = now;
      if (/^\/title\/tt\d+/.test(location.pathname)) {
        // small delay to let DOM settle
        setTimeout(() => { ensureModal(); }, 350);
      } else {
        removeExisting();
      }
    }
  }
  (function () {
    const wrap = function (type) {
      const orig = history[type];
      return function () {
        const ret = orig.apply(this, arguments);
        setTimeout(checkUrlChange, 60);
        return ret;
      };
    };
    history.pushState = wrap('pushState');
    history.replaceState = wrap('replaceState');
    window.addEventListener('popstate', checkUrlChange);
    // polling fallback
    setInterval(checkUrlChange, 900);
  })();

  // Expose small helper in window for manual testing
  try {
    window.__IMDbModal = {
      ensureModal,
      removeExisting,
      clearClosedFlag: () => { sessionStorage.removeItem(STORAGE_KEY); console.log('[IMDbModal] closed flag cleared'); }
    };
    console.log('[IMDbModal] helper exposed: window.__IMDbModal (use ensureModal(), removeExisting(), clearClosedFlag())');
  } catch (e) {
    // ignore
  }
})();
