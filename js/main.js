/* =============================================================
   Tyler Everage — Portfolio interactions
   Lightweight, dependency-free, respectful of reduced motion.
   ============================================================= */

(function () {
  "use strict";

  const reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  /* ---------- Footer year ---------- */
  const yearEl = document.getElementById("year");
  if (yearEl) yearEl.textContent = new Date().getFullYear();

  /* ---------- Loader ---------- */
  const loader = document.getElementById("loader");
  const hero = document.getElementById("hero");
  window.addEventListener("load", () => {
    setTimeout(() => {
      if (loader) loader.classList.add("is-done");
      if (hero) hero.classList.add("is-in");
    }, reduceMotion ? 0 : 1100);
  });
  // Safety: if load already fired or is slow, reveal hero anyway.
  setTimeout(() => {
    if (loader) loader.classList.add("is-done");
    if (hero) hero.classList.add("is-in");
  }, 2200);

  /* ---------- Scroll reveal ---------- */
  const revealEls = document.querySelectorAll(".reveal");
  if ("IntersectionObserver" in window && !reduceMotion) {
    const io = new IntersectionObserver(
      (entries) => {
        entries.forEach((entry) => {
          if (entry.isIntersecting) {
            entry.target.classList.add("is-in");
            io.unobserve(entry.target);
          }
        });
      },
      { threshold: 0.15, rootMargin: "0px 0px -8% 0px" }
    );
    revealEls.forEach((el) => io.observe(el));
  } else {
    revealEls.forEach((el) => el.classList.add("is-in"));
  }

  /* ---------- Nav: hide on scroll down, show on up + scrolled bg ---------- */
  const nav = document.getElementById("nav");
  let lastY = window.scrollY;
  let ticking = false;
  function onScroll() {
    const y = window.scrollY;
    if (nav) {
      nav.classList.toggle("is-scrolled", y > 40);
      if (y > lastY && y > 300) nav.classList.add("is-hidden");
      else nav.classList.remove("is-hidden");
    }
    lastY = y;
    ticking = false;
  }
  window.addEventListener(
    "scroll",
    () => {
      if (!ticking) {
        window.requestAnimationFrame(onScroll);
        ticking = true;
      }
    },
    { passive: true }
  );

  /* ---------- Custom cursor ---------- */
  const cursor = document.querySelector(".cursor");
  const dot = document.querySelector(".cursor__dot");
  const ring = document.querySelector(".cursor__ring");
  const fine = window.matchMedia("(hover: hover) and (pointer: fine)").matches;

  if (cursor && fine && !reduceMotion) {
    let mx = window.innerWidth / 2, my = window.innerHeight / 2;
    let rx = mx, ry = my;

    window.addEventListener("mousemove", (e) => {
      mx = e.clientX; my = e.clientY;
      dot.style.transform = `translate(${mx}px, ${my}px) translate(-50%, -50%)`;
    });

    function loop() {
      rx += (mx - rx) * 0.18;
      ry += (my - ry) * 0.18;
      ring.style.transform = `translate(${rx}px, ${ry}px) translate(-50%, -50%)`;
      requestAnimationFrame(loop);
    }
    loop();

    document.querySelectorAll("[data-hover]").forEach((el) => {
      el.addEventListener("mouseenter", () => cursor.classList.add("is-hover"));
      el.addEventListener("mouseleave", () => cursor.classList.remove("is-hover"));
    });
  } else if (cursor) {
    cursor.style.display = "none";
  }

  /* ---------- Magnetic buttons ---------- */
  if (fine && !reduceMotion) {
    document.querySelectorAll("[data-magnetic]").forEach((el) => {
      const strength = 0.3;
      el.addEventListener("mousemove", (e) => {
        const r = el.getBoundingClientRect();
        const x = e.clientX - (r.left + r.width / 2);
        const y = e.clientY - (r.top + r.height / 2);
        el.style.transform = `translate(${x * strength}px, ${y * strength}px)`;
      });
      el.addEventListener("mouseleave", () => {
        el.style.transform = "translate(0, 0)";
      });
    });
  }

  /* ---------- Subtle card tilt ---------- */
  if (fine && !reduceMotion) {
    document.querySelectorAll("[data-tilt]").forEach((card) => {
      const inner = card.querySelector(".project__inner") || card;
      const max = 5;
      card.addEventListener("mousemove", (e) => {
        const r = card.getBoundingClientRect();
        const px = (e.clientX - r.left) / r.width - 0.5;
        const py = (e.clientY - r.top) / r.height - 0.5;
        inner.style.transform = `perspective(900px) rotateX(${(-py * max).toFixed(2)}deg) rotateY(${(px * max).toFixed(2)}deg) translateY(-4px)`;
      });
      card.addEventListener("mouseleave", () => {
        inner.style.transform = "perspective(900px) rotateX(0) rotateY(0) translateY(0)";
      });
    });
  }

  /* ---------- Parallax on background blobs ---------- */
  if (!reduceMotion) {
    const blobs = document.querySelectorAll(".blob");
    window.addEventListener(
      "scroll",
      () => {
        const y = window.scrollY;
        blobs.forEach((b, i) => {
          const speed = (i + 1) * 0.03;
          b.style.translate = `0 ${y * speed}px`;
        });
      },
      { passive: true }
    );
  }
})();
