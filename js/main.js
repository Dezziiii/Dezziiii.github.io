/* =====================================================================
   Tyler — Portfolio interactions  (vanilla JS, no dependencies)
   Flashy where it counts; fully gated behind prefers-reduced-motion.
   ===================================================================== */
(function () {
  "use strict";

  const prefersReduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  const finePointer = window.matchMedia("(pointer: fine)").matches;
  const $  = (s, c = document) => c.querySelector(s);
  const $$ = (s, c = document) => Array.from(c.querySelectorAll(s));
  const lerp = (a, b, n) => a + (b - a) * n;

  /* Load the intro once per session; later tab switches skip the loader and
     reveal content instantly (see .vt-nav in CSS) for a quick animated swap. */
  const introSeen = document.documentElement.classList.contains("vt-nav");
  try { sessionStorage.setItem("introSeen", "1"); } catch (e) {}

  /* ---------- Page-swap curtain (works regardless of document visibility) ---------- */
  (function () {
    const curtain = $("[data-curtain]");
    if (!curtain || prefersReduced) return;
    const EASE_IN = "transform 0.42s cubic-bezier(0.76, 0, 0.24, 1)";
    const EASE_OUT = "transform 0.55s cubic-bezier(0.76, 0, 0.24, 1)";

    // ENTER: on a navigation the curtain already covers (CSS .vt-nav) — lift it away.
    if (introSeen) {
      curtain.style.transform = "translateY(0)";
      requestAnimationFrame(() => {
        curtain.style.transition = EASE_OUT;
        requestAnimationFrame(() => { curtain.style.transform = "translateY(-100%)"; });
      });
      curtain.addEventListener("transitionend", () => {
        curtain.style.transition = "none";
        curtain.style.transform = "translateY(100%)";   // park below for the next exit
      }, { once: true });
    }

    // EXIT: cover the screen, then navigate (so the reload happens behind the curtain).
    let leaving = false;
    document.addEventListener("click", (e) => {
      if (leaving || e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
      const a = e.target.closest("a[href]");
      if (!a || a.target === "_blank" || a.hasAttribute("download")) return;
      let url; try { url = new URL(a.getAttribute("href"), location.href); } catch (_) { return; }
      if (url.origin !== location.origin) return;
      if (!/\.html$/.test(url.pathname)) return;   // any internal page on the site
      if (url.pathname === location.pathname) return;   // same page (hash link) — leave it
      e.preventDefault();
      leaving = true;
      let went = false;
      const go = () => { if (went) return; went = true; window.location.href = a.href; };
      curtain.style.transition = "none";
      curtain.style.transform = "translateY(100%)";
      requestAnimationFrame(() => {
        curtain.style.transition = EASE_IN;
        requestAnimationFrame(() => { curtain.style.transform = "translateY(0)"; });
      });
      curtain.addEventListener("transitionend", go, { once: true });
      setTimeout(go, 650);   // fallback
    });
  })();

  /* ---------- Footer year ---------- */
  const yearEl = $("[data-year]");
  if (yearEl) yearEl.textContent = new Date().getFullYear();

  /* ---------- Hero: wrap each title line for the mask reveal ---------- */
  $$(".hero__title .line").forEach((line) => {
    const inner = document.createElement("span");
    inner.className = "line__inner";
    while (line.firstChild) inner.appendChild(line.firstChild);
    line.appendChild(inner);
  });

  /* ---------- Split big titles into animated words ---------- */
  const splitWords = (el) => {
    const frag = document.createDocumentFragment();
    Array.from(el.childNodes).forEach((node) => {
      if (node.nodeType === 3) {
        node.textContent.split(/(\s+)/).forEach((token) => {
          if (token.trim() === "") { frag.appendChild(document.createTextNode(token)); return; }
          const word = document.createElement("span"); word.className = "word";
          const inner = document.createElement("span"); inner.className = "word__inner"; inner.textContent = token;
          word.appendChild(inner); frag.appendChild(word);
        });
      } else {
        frag.appendChild(node.cloneNode(true)); // preserve <br> etc.
      }
    });
    el.textContent = ""; el.appendChild(frag); el.classList.add("split");
    $$(".word__inner", el).forEach((inner, i) => { inner.style.transitionDelay = (i * 0.05) + "s"; });
  };
  $$(".section__title, .contact__title").forEach(splitWords);

  /* ---------- Reveal-on-scroll + count-up (rect based: reliable with smooth scroll) ---------- */
  const revealEls = $$("[data-reveal]");
  const countEls = $$("[data-count]");
  const fmtCount = (n) => "[" + String(n).padStart(2, "0") + "]";
  const animateCount = (el) => {
    const target = parseInt(el.dataset.count, 10) || 0;
    if (prefersReduced) { el.textContent = fmtCount(target); return; }
    const dur = 900, start = performance.now();
    const step = (now) => {
      const t = Math.min((now - start) / dur, 1);
      const e = 1 - Math.pow(1 - t, 3);
      el.textContent = fmtCount(Math.round(e * target));
      if (t < 1) requestAnimationFrame(step);
    };
    requestAnimationFrame(step);
  };
  const inView = (el, pad) => {
    const r = el.getBoundingClientRect();
    return r.top < window.innerHeight * (1 - pad) && r.bottom > 0;
  };
  const runChecks = () => {
    revealEls.forEach((el) => { if (!el.classList.contains("is-visible") && inView(el, 0.12)) el.classList.add("is-visible"); });
    countEls.forEach((el) => { if (!el._counted && inView(el, 0)) { el._counted = true; animateCount(el); } });
  };
  let checkTicking = false;
  const requestChecks = () => { if (!checkTicking) { checkTicking = true; requestAnimationFrame(() => { checkTicking = false; runChecks(); }); } };
  if (prefersReduced) {
    revealEls.forEach((el) => el.classList.add("is-visible"));
    countEls.forEach((el) => animateCount(el));
  } else {
    window.addEventListener("scroll", requestChecks, { passive: true });
    window.addEventListener("resize", requestChecks);
    runChecks();
  }

  /* ---------- In-page anchor links (native #anchor scrolling fails under the
       transform-based smooth scroll, so scroll the window manually) ---------- */
  const navOffset = () => {
    const navEl = $(".nav");
    return (navEl ? navEl.getBoundingClientRect().bottom : 72) + 16;
  };
  const scrollToTarget = (el) => {
    if (!el) return;
    const y = Math.max(0, window.scrollY + el.getBoundingClientRect().top - navOffset());
    window.scrollTo(0, y);
  };
  const handleInitialHash = () => {
    if (!location.hash || location.hash === "#top") return;
    const el = document.querySelector(location.hash);
    if (el) requestAnimationFrame(() => requestAnimationFrame(() => scrollToTarget(el)));
  };
  document.addEventListener("click", (e) => {
    const a = e.target.closest("a[href]");
    if (!a || e.defaultPrevented || e.button !== 0 || e.metaKey || e.ctrlKey || e.shiftKey || e.altKey) return;
    const href = a.getAttribute("href");
    if (!href) return;
    let hash = null;
    if (href[0] === "#") hash = href;
    else {
      try {
        const u = new URL(href, location.href);
        if (u.origin === location.origin && u.pathname === location.pathname && u.hash) hash = u.hash;
      } catch (_) {}
    }
    if (!hash) return;
    if (hash === "#" || hash === "#top") { e.preventDefault(); window.scrollTo(0, 0); history.pushState(null, "", location.pathname); return; }
    const el = document.querySelector(hash);
    if (!el) return;
    e.preventDefault();
    scrollToTarget(el);
    history.pushState(null, "", hash);
  });

  /* ---------- Intro loader ---------- */
  const loader = $("[data-loader]");
  const finishLoad = () => {
    document.body.classList.add("is-loaded");
    enableSmooth();
    initBlobParallax();
    requestChecks();
    handleInitialHash();
  };
  if (prefersReduced || introSeen) {
    if (loader) loader.remove();
    finishLoad();
  } else if (loader) {
    document.body.style.overflow = "hidden";
    const countEl = $("[data-loader-count]"), bar = $("[data-loader-bar]");
    // Constantly-scrambling binary digits while loading.
    const binEls = $$(".loader__binary span");
    const randBin = () => {
      const len = 2 + Math.floor(Math.random() * 8);
      let s = "";
      for (let i = 0; i < len; i++) s += (Math.random() < 0.5 ? "0" : "1") + (Math.random() < 0.22 ? " " : "");
      return s.trim();
    };
    const binTimer = binEls.length ? setInterval(() => binEls.forEach((e) => (e.textContent = randBin())), 80) : null;
    let p = 0;
    const tick = () => {
      p = Math.min(100, p + Math.random() * 9 + 4);
      if (countEl) countEl.textContent = Math.floor(p);
      if (bar) bar.style.width = p + "%";
      if (p < 100) { setTimeout(tick, 80 + Math.random() * 90); }
      else {
        if (binTimer) clearInterval(binTimer);
        setTimeout(() => {
          loader.classList.add("is-done");
          document.body.style.overflow = "";
          finishLoad();
          loader.addEventListener("transitionend", () => loader.remove(), { once: true });
        }, 280);
      }
    };
    tick();
  } else {
    finishLoad();
  }

  /* ---------- Nav: frosted background on scroll ---------- */
  const nav = $("[data-nav]");
  const onNavScroll = () => nav.classList.toggle("is-scrolled", window.scrollY > 24);
  onNavScroll();
  window.addEventListener("scroll", onNavScroll, { passive: true });

  /* ---------- Nav: mobile menu ---------- */
  const toggle = $(".nav__toggle");
  if (toggle) {
    const closeMenu = () => {
      nav.classList.remove("is-open");
      toggle.setAttribute("aria-expanded", "false");
      toggle.setAttribute("aria-label", "Open menu");
    };
    toggle.addEventListener("click", () => {
      const open = nav.classList.toggle("is-open");
      toggle.setAttribute("aria-expanded", String(open));
      toggle.setAttribute("aria-label", open ? "Close menu" : "Open menu");
    });
    $$(".nav__links a").forEach((a) => a.addEventListener("click", closeMenu));
    document.addEventListener("keydown", (e) => { if (e.key === "Escape") closeMenu(); });
  }

  /* ---------- Decorative EN/FR toggle ---------- */
  const langBtn = $(".nav__lang");
  if (langBtn) langBtn.addEventListener("click", () => {
    $$("span", langBtn).forEach((s) => s.textContent !== "/" && s.classList.toggle("is-on"));
  });

  /* ---------- Scrollspy (level/character map to "Work") ---------- */
  const navLinks = $$(".nav__links a[href^='#']");
  const spyMap = { work: "work", capabilities: "work", level: "work", character: "work", about: "work", contact: "work" };
  const spySections = $$("section[id]").filter((s) => spyMap[s.id]);
  let spyTicking = false;
  const spyUpdate = () => {
    spyTicking = false;
    const pos = window.scrollY + window.innerHeight * 0.3;
    let current = null;
    spySections.forEach((s) => { if (s.offsetTop <= pos) current = spyMap[s.id]; });
    navLinks.forEach((a) => a.classList.toggle("is-active", a.getAttribute("href") === "#" + current));
  };
  const spyRequest = () => { if (!spyTicking) { spyTicking = true; requestAnimationFrame(spyUpdate); } };
  spyUpdate();
  window.addEventListener("scroll", spyRequest, { passive: true });

  /* ---------- Copy-to-clipboard email ---------- */
  $$("[data-copy]").forEach((btn) => {
    const hint = btn.querySelector(".contact__email-hint");
    const original = hint ? hint.textContent : "";
    btn.addEventListener("click", async () => {
      try {
        await navigator.clipboard.writeText(btn.dataset.copy);
        btn.classList.add("is-copied");
        if (hint) hint.textContent = "Copied ✓";
        setTimeout(() => { btn.classList.remove("is-copied"); if (hint) hint.textContent = original; }, 1800);
      } catch (_) { window.location.href = "mailto:" + btn.dataset.copy; }
    });
  });

  /* ---------- Text scramble on hover ---------- */
  if (!prefersReduced) {
    const CH = "ABCDEFGHIJKLMNOPQRSTUVWXYZ#%@*";
    $$("[data-scramble]").forEach((el) => {
      const orig = el.textContent;
      el.addEventListener("mouseenter", () => {
        let pos = 0;
        clearInterval(el._scr);
        el._scr = setInterval(() => {
          el.textContent = orig.split("").map((ch, i) =>
            (i < pos || ch === " ") ? orig[i] : CH[Math.floor(Math.random() * CH.length)]
          ).join("");
          pos += 1;
          if (pos > orig.length) { clearInterval(el._scr); el.textContent = orig; }
        }, 26);
      });
    });
  }

  /* ---------- Video-on-hover (no-op until a <video> is added to a card) ---------- */
  $$(".fcard__media, .card__media").forEach((media) => {
    const v = media.querySelector("video"); if (!v) return;
    const trigger = media.closest("a") || media;
    trigger.addEventListener("mouseenter", () => { const pr = v.play(); if (pr && pr.catch) pr.catch(() => {}); });
    trigger.addEventListener("mouseleave", () => { v.pause(); try { v.currentTime = 0; } catch (_) {} });
  });

  /* ---------- Theme toggle (persisted; applied pre-paint by inline <head> script) ---------- */
  (function () {
    const root = document.documentElement;
    const metaColor = (t) => { const m = document.querySelector('meta[name="theme-color"]'); if (m) m.setAttribute("content", t === "dark" ? "#1B130D" : "#F4ECE0"); };
    metaColor(root.getAttribute("data-theme") === "dark" ? "dark" : "light");
    $$("[data-theme-toggle]").forEach((b) => b.addEventListener("click", () => {
      const next = root.getAttribute("data-theme") === "dark" ? "light" : "dark";
      if (next === "dark") root.setAttribute("data-theme", "dark"); else root.removeAttribute("data-theme");
      try { localStorage.setItem("theme", next); } catch (e) {}
      metaColor(next);
    }));
  })();

  /* ---------- Live clock in the status ticker ---------- */
  (function () {
    const els = $$("[data-clock]"); if (!els.length) return;
    const p = (n) => String(n).padStart(2, "0");
    const tick = () => { const d = new Date(); const s = p(d.getHours()) + ":" + p(d.getMinutes()) + ":" + p(d.getSeconds()); els.forEach((e) => (e.textContent = s)); };
    tick(); setInterval(tick, 1000);
  })();

  /* ---------- Date stamps (letter + receipt) ---------- */
  (function () {
    const els = $$("[data-date], [data-r-date]"); if (!els.length) return;
    const str = new Date().toLocaleDateString("en-GB", { day: "2-digit", month: "short", year: "numeric" }).toUpperCase();
    els.forEach((e) => (e.textContent = str));
  })();

  /* ---------- Writing: click a log to expand & read it ---------- */
  (function () {
    const logs = $("[data-logs]"); if (!logs) return;
    logs.addEventListener("click", (e) => {
      const head = e.target.closest(".entry__head"); if (!head) return;
      const entry = head.closest(".entry");
      const open = entry.classList.toggle("is-open");
      head.setAttribute("aria-expanded", String(open));
      requestChecks();   // content height changed — keep reveals in sync
    });
  })();

  /* ---------- Contact: letter form + signature pad + mailto ---------- */
  (function () {
    const letter = $("[data-letter]"); if (!letter) return;
    const chips = $("[data-chips]"), nameI = $("[data-name]"), emailI = $("[data-from-email]"), noteI = $("[data-note]");
    const rSub = $("[data-r-subject]"), rFrom = $("[data-r-from]"), rStatus = $("[data-r-status]");
    let subject = "A new role";

    if (chips) chips.addEventListener("click", (e) => {
      const c = e.target.closest(".chip"); if (!c) return;
      $$(".chip", chips).forEach((x) => x.classList.toggle("is-on", x === c));
      subject = c.dataset.subject; if (rSub) rSub.textContent = subject;
    });
    if (nameI) nameI.addEventListener("input", () => { if (rFrom) rFrom.textContent = nameI.value.trim() || "——"; });

    /* Signature pad */
    const pad = $("[data-sign]");
    if (pad) {
      const canvas = pad.querySelector("canvas"), ctx = canvas.getContext("2d");
      let drawing = false, last = null, signed = false;
      const dpr = Math.min(window.devicePixelRatio || 1, 2);
      const setup = () => {
        const r = pad.getBoundingClientRect();
        canvas.width = r.width * dpr; canvas.height = r.height * dpr;   // resets ctx state
        ctx.scale(dpr, dpr);
        ctx.lineWidth = 2; ctx.lineCap = "round"; ctx.lineJoin = "round";
        ctx.strokeStyle = (getComputedStyle(document.documentElement).getPropertyValue("--ink").trim()) || "#2A1E14";
      };
      setup();
      window.addEventListener("resize", setup);
      const at = (e) => { const r = canvas.getBoundingClientRect(); return { x: e.clientX - r.left, y: e.clientY - r.top }; };
      canvas.addEventListener("pointerdown", (e) => {
        drawing = true; last = at(e);
        if (!signed) { signed = true; pad.classList.add("is-signed"); if (rStatus) rStatus.textContent = "Signed"; }
        e.preventDefault();
      });
      canvas.addEventListener("pointermove", (e) => {
        if (!drawing) return; const p = at(e);
        ctx.beginPath(); ctx.moveTo(last.x, last.y); ctx.lineTo(p.x, p.y); ctx.stroke(); last = p; e.preventDefault();
      });
      window.addEventListener("pointerup", () => { drawing = false; });
      const clear = $("[data-sign-clear]");
      if (clear) clear.addEventListener("click", () => {
        ctx.clearRect(0, 0, canvas.width, canvas.height); signed = false;
        pad.classList.remove("is-signed"); if (rStatus) rStatus.textContent = "Being written";
      });
    }

    /* Send → compose a mailto */
    const send = $("[data-send]"), toast = $("[data-toast]");
    if (send) send.addEventListener("click", () => {
      const name = nameI ? nameI.value.trim() : "", note = noteI ? noteI.value.trim() : "";
      const from = emailI && emailI.value ? emailI.value.trim() : "";
      const subj = encodeURIComponent(subject + (name ? " — " + name : ""));
      const body = encodeURIComponent((note || "Hi Tyler,") + "\n\n— " + name + (from ? " (" + from + ")" : ""));
      window.location.href = "mailto:" + send.dataset.email + "?subject=" + subj + "&body=" + body;
      if (toast) { toast.textContent = "Opening your mail app…"; toast.classList.add("is-on"); setTimeout(() => toast.classList.remove("is-on"), 2600); }
    });
  })();

  /* ===================================================================
     Smooth inertial scroll  (fine pointers, non-reduced only)
     Native scroll is preserved; we just visually follow with a lag.
     =================================================================== */
  function enableSmooth() {
    if (!finePointer || prefersReduced) return;
    const wrap = $("#smooth"); if (!wrap) return;
    document.documentElement.style.scrollBehavior = "auto";
    document.body.classList.add("smooth-on");
    let current = window.scrollY || 0;
    const setHeight = () => { document.body.style.height = wrap.offsetHeight + "px"; };
    setHeight();
    if ("ResizeObserver" in window) new ResizeObserver(setHeight).observe(wrap);
    window.addEventListener("load", setHeight);
    window.addEventListener("resize", setHeight);
    const loop = () => {
      const target = window.scrollY;
      current = lerp(current, target, 0.09);
      if (Math.abs(target - current) < 0.06) current = target;
      else requestChecks();                       // keep reveals in sync while settling
      wrap.style.transform = `translate3d(0, ${-current}px, 0)`;
      requestAnimationFrame(loop);
    };
    loop();
  }

  /* ---------- Background blob parallax (mouse + scroll depth) ---------- */
  function initBlobParallax() {
    if (prefersReduced) return;
    const blobs = $(".blobs"); if (!blobs) return;
    let mx = 0, my = 0, tmx = 0, tmy = 0;
    if (finePointer) {
      window.addEventListener("mousemove", (e) => {
        tmx = (e.clientX / window.innerWidth - 0.5) * 42;
        tmy = (e.clientY / window.innerHeight - 0.5) * 42;
      });
    }
    const loop = () => {
      mx = lerp(mx, tmx, 0.06); my = lerp(my, tmy, 0.06);
      const drift = Math.min((window.scrollY || 0) * 0.03, 120);
      blobs.style.transform = `translate3d(${mx}px, ${my + drift}px, 0)`;
      requestAnimationFrame(loop);
    };
    loop();
  }

  /* ===================================================================
     Custom cursor + magnetic  (fine pointers, non-reduced only)
     =================================================================== */
  if (finePointer && !prefersReduced) {
    const cursor = $(".cursor"), label = $(".cursor__label");
    if (cursor) {
      cursor.style.display = "grid";
      document.body.classList.add("cursor-on");   // hide the native cursor; the dot takes over
      let cx = innerWidth / 2, cy = innerHeight / 2, tx = cx, ty = cy;
      const showCursor = () => cursor.classList.add("is-active");
      // Re-show on every move / re-entry (not a one-time flag), so leaving the
      // window and coming back never leaves the cursor stuck invisible.
      addEventListener("mousemove", (e) => { tx = e.clientX; ty = e.clientY; showCursor(); });
      addEventListener("pointerdown", showCursor);
      document.addEventListener("mouseenter", showCursor);
      document.addEventListener("mouseleave", () => cursor.classList.remove("is-active"));
      (function render() {
        cx = lerp(cx, tx, 0.18); cy = lerp(cy, ty, 0.18);
        cursor.style.transform = `translate(${cx}px, ${cy}px) translate(-50%, -50%)`;
        requestAnimationFrame(render);
      })();
      $$("a, button, [data-magnetic]").forEach((el) => {
        el.addEventListener("mouseenter", () => cursor.classList.add("is-hover"));
        el.addEventListener("mouseleave", () => cursor.classList.remove("is-hover"));
      });
      $$("[data-cursor]").forEach((el) => {
        el.addEventListener("mouseenter", () => { cursor.classList.add("is-media"); if (label) label.textContent = el.dataset.cursor; });
        el.addEventListener("mouseleave", () => { cursor.classList.remove("is-media"); if (label) label.textContent = ""; });
      });
    }
    $$("[data-magnetic]").forEach((el) => {
      const strength = 0.3;
      el.addEventListener("mousemove", (e) => {
        const r = el.getBoundingClientRect();
        el.style.transform = `translate(${(e.clientX - (r.left + r.width / 2)) * strength}px, ${(e.clientY - (r.top + r.height / 2)) * strength}px)`;
      });
      el.addEventListener("mouseleave", () => { el.style.transform = ""; });
    });
  }
})();
