const header = document.querySelector(".site-header");
const menuButton = document.querySelector(".menu-button");
const nav = document.querySelector(".nav");
const form = document.querySelector(".signup-form");
const formNote = document.querySelector(".form-note");
const cursorGlow = document.querySelector(".cursor-glow");

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
  formNote.textContent = "You're on the list. Welcome to Wayaki.";
  form.reset();
});

const revealItems = [
  ...document.querySelectorAll(
    ".brand-statement, .category-proof article, .manifesto-kicker, .manifesto-copy, .section-heading, .feature-card, .steps-copy, .steps-list li, .price-card, .technology-heading, .tech-rail, .system-console, .reach-copy, .map-card, .trust-heading, .trust-stack article, .company-quote, .company-story, .cta-section, .trust-grid"
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
