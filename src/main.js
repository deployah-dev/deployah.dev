import "./fonts.css";
import "./styles.css";
import ClipboardJS from "clipboard";

const navToggle = document.querySelector(".nav-toggle");
const nav = document.getElementById("primary-nav");

if (navToggle && nav) {
  const desk = window.matchMedia("(min-width: 40rem)");

  const setInvoker = (open) => {
    navToggle.setAttribute("aria-expanded", open ? "true" : "false");
    navToggle.setAttribute("aria-label", open ? "Close menu" : "Open menu");
  };

  const enablePopover = () => {
    nav.setAttribute("popover", "");
    navToggle.setAttribute("popovertarget", "primary-nav");
    setInvoker(nav.matches(":popover-open"));
  };

  const disablePopover = () => {
    if (nav.hasAttribute("popover") && nav.matches(":popover-open")) {
      nav.hidePopover();
    }
    nav.removeAttribute("popover");
    navToggle.removeAttribute("popovertarget");
    setInvoker(false);
  };

  const syncPopover = () => {
    if (desk.matches) disablePopover();
    else enablePopover();
  };

  syncPopover();
  desk.addEventListener("change", syncPopover);

  nav.addEventListener("toggle", (event) => {
    setInvoker(event.newState === "open");
  });

  nav.addEventListener("click", (event) => {
    if (!event.target.closest("a") || !nav.hasAttribute("popover")) return;
    nav.hidePopover();
  });
}

const installGroup = document.querySelector(".install-tabs");
const installCmd = document.querySelector("[data-install-cmd]");
const installCopy = document.querySelector("#install-panel .copy");

const applyInstall = (input) => {
  if (!installCmd || !installCopy) return;
  const cmd = input.dataset.cmd ?? "";
  installCmd.textContent = cmd;
  installCopy.dataset.clipboardText = cmd;
  installCopy.setAttribute("aria-label", input.dataset.copyLabel ?? "Copy install command");
  installCopy.textContent = "Copy";
  delete installCopy.dataset.busy;
};

installGroup?.addEventListener("change", (event) => {
  const input = event.target;
  if (!(input instanceof HTMLInputElement) || input.name !== "install") return;
  applyInstall(input);
});

const clipboard = new ClipboardJS(".copy");

clipboard.on("success", (e) => {
  const btn = e.trigger;
  if (btn.dataset.busy) return;
  btn.dataset.busy = "1";
  btn.textContent = "Copied";
  e.clearSelection();
  window.setTimeout(() => {
    btn.textContent = "Copy";
    delete btn.dataset.busy;
  }, 1500);
});

clipboard.on("error", (e) => {
  e.trigger.textContent = "Copy failed";
  window.setTimeout(() => {
    e.trigger.textContent = "Copy";
  }, 1500);
});

const demoOpen = document.querySelector(".hero-demo-open");
const demoDialog = document.getElementById("hero-demo-dialog");
const demoVideo = demoDialog?.querySelector("video");

if (demoOpen && demoDialog && demoVideo) {
  demoOpen.addEventListener("click", () => {
    demoDialog.showModal();
    demoVideo.play().catch(() => {});
  });

  demoDialog.addEventListener("click", (event) => {
    if (event.target === demoDialog) demoDialog.close();
  });

  demoDialog.addEventListener("close", () => {
    demoVideo.pause();
  });
}

const motion = window.matchMedia("(prefers-reduced-motion: reduce)");
document.querySelectorAll(".laptop-loop").forEach((video) => {
  video.addEventListener("playing", () => {
    video.classList.add("is-playing");
  });
  const playIfOk = () => {
    if (motion.matches) {
      video.pause();
      video.classList.remove("is-playing");
      return;
    }
    video.play().catch(() => {});
  };
  const io = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        if (entry.isIntersecting) playIfOk();
        else video.pause();
      }
    },
    { threshold: 0.35 },
  );
  const shot = video.closest(".laptop-shot") ?? video;
  io.observe(shot);
  motion.addEventListener("change", playIfOk);
});
