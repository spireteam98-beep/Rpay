const header = document.querySelector(".site-header");
const menuButton = document.querySelector(".menu-button");
const nav = document.querySelector(".nav");
const form = document.querySelector(".signup-form");
const formNote = document.querySelector(".form-note");
const cursorGlow = document.querySelector(".cursor-glow");
const appTransition = document.getElementById("app-transition");

/* -- warm the Flutter app's heavy boot assets (main.dart.js + CanvasKit wasm)
   before the visitor ever clicks, so the hand-off feels instant instead of
   making them wait ~10MB of cold downloads on click -- */
const APP_BOOT_ASSETS = [
  "/app/flutter_bootstrap.js",
  "/app/flutter.js",
  "/app/main.dart.js",
  "/app/canvaskit/canvaskit.js",
  "/app/canvaskit/canvaskit.wasm",
];
let appPrefetched = false;
function prefetchApp() {
  if (appPrefetched) return;
  appPrefetched = true;
  APP_BOOT_ASSETS.forEach((url) => {
    const link = document.createElement("link");
    link.rel = "prefetch";
    link.href = url;
    document.head.appendChild(link);
    fetch(url, { cache: "force-cache" }).catch(() => {});
  });
}
if ("requestIdleCallback" in window) {
  requestIdleCallback(prefetchApp, { timeout: 3000 });
} else {
  setTimeout(prefetchApp, 1500);
}

/* -- instant branded hand-off: show the transition overlay synchronously on
   click (before the browser starts tearing down this page) so there's no
   blank flash / "two different pages" feeling, then navigate -- */
document.querySelectorAll('a[href^="/app/"]').forEach((link) => {
  link.addEventListener("pointerenter", prefetchApp, { once: true });
  link.addEventListener("touchstart", prefetchApp, { once: true, passive: true });
  link.addEventListener("click", (event) => {
    event.preventDefault();
    prefetchApp();
    appTransition.classList.add("show");
    const dest = link.href;
    requestAnimationFrame(() => {
      requestAnimationFrame(() => {
        window.location.href = dest;
      });
    });
  });
});

window.addEventListener("scroll", () => {
  header.classList.toggle("scrolled", window.scrollY > 24);
}, { passive: true });

menuButton.addEventListener("click", () => {
  const open = nav.classList.toggle("menu-open");
  menuButton.setAttribute("aria-expanded", String(open));
  menuButton.setAttribute("aria-label", open ? "Close menu" : "Open menu");
});

document.querySelectorAll(".nav-links a").forEach((link) => {
  link.addEventListener("click", () => {
    nav.classList.remove("menu-open");
    menuButton.setAttribute("aria-expanded", "false");
  });
});

form.addEventListener("submit", (event) => {
  event.preventDefault();
  const email = new FormData(form).get("email").trim();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    formNote.textContent = "Enter a valid email address to continue.";
    return;
  }
  formNote.textContent = "Opening your secure Wayaki signup…";
  prefetchApp();
  appTransition.classList.add("show");
  const dest = `/app/#/?screen=email_verify&email=${encodeURIComponent(email.toLowerCase())}`;
  requestAnimationFrame(() => {
    requestAnimationFrame(() => {
      window.location.href = dest;
    });
  });
});

const revealItems = [
  ...document.querySelectorAll(
    ".brand-statement, .category-proof article, .manifesto-kicker, .manifesto-copy, .section-heading, .feature-card, .technology-heading, .tech-rail, .system-console, .reach-copy, .map-card, .trust-heading, .trust-stack article, .company-quote, .company-story, .cta-section, .trust-grid"
  ),
];

revealItems.forEach((item, index) => {
  item.classList.add("reveal", `reveal-delay-${index % 3}`);
});

const revealObserver = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry) => {
      if (entry.isIntersecting) {
        entry.target.classList.add("is-visible");
        revealObserver.unobserve(entry.target);
      }
    });
  },
  { threshold: 0.14 }
);

revealItems.forEach((item) => revealObserver.observe(item));

if (window.matchMedia("(pointer: fine)").matches) {
  window.addEventListener("pointermove", (event) => {
    cursorGlow.style.opacity = "1";
    cursorGlow.style.left = `${event.clientX}px`;
    cursorGlow.style.top = `${event.clientY}px`;
  });

  document.querySelectorAll(".feature-card").forEach((card) => {
    card.addEventListener("pointermove", (event) => {
      const bounds = card.getBoundingClientRect();
      const x = (event.clientX - bounds.left) / bounds.width - 0.5;
      const y = (event.clientY - bounds.top) / bounds.height - 0.5;
      card.style.transform = `perspective(1000px) rotateY(${x * 7}deg) rotateX(${
        y * -7
      }deg) translateY(-5px)`;
    });

    card.addEventListener("pointerleave", () => {
      card.style.transform = "";
    });
  });
}
