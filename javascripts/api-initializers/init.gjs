// {theme}/javascripts/discourse/api-initializers/init-theme.gjs
import { apiInitializer } from "discourse/lib/api";
import { schedule } from "@ember/runloop";

// Doc categories, detected by the plugin's sidebar panel or known slugs.
const DOC_CATEGORY_SLUGS = ["glosario", "wiki", "trading-curso"];
const DOC_SIDEBAR_SEEN_KEY = "horizon-mods-doc-sidebar-seen";

function isDocCategoryPage() {
  if (document.querySelector(".discourse-docs-sidebar-panel")) {
    return true;
  }
  return DOC_CATEGORY_SLUGS.some((slug) =>
    document.body.classList.contains(`category-${slug}`)
  );
}

// Per-category key — one shared key marked all three seen at once.
function docSidebarSeenKey() {
  const slug = DOC_CATEGORY_SLUGS.find((s) =>
    document.body.classList.contains(`category-${s}`)
  );
  return `${DOC_SIDEBAR_SEEN_KEY}-${slug ?? "other"}`;
}

// #toggle-hamburger-menu is the real button; the rest are harmless fallbacks.
function findSidebarToggleButton() {
  return (
    document.querySelector("#toggle-hamburger-menu") ||
    document.querySelector(".hamburger-dropdown button") ||
    document.querySelector(".btn-sidebar-toggle") ||
    document.querySelector(".header-sidebar-toggle button") ||
    document.querySelector(".header-sidebar-toggle") ||
    document.querySelector('button[aria-label*="sidebar" i]') ||
    document.querySelector('[data-identifier="sidebar-toggle"]')
  );
}

// Auto-opens the sidebar once per category per session.
function autoOpenDocSidebar() {
  if (!window.matchMedia("(max-width: 576px)").matches) {
    return;
  }

  if (!isDocCategoryPage()) {
    return;
  }

  const seenKey = docSidebarSeenKey();

  let seen;
  try {
    seen = sessionStorage.getItem(seenKey);
  } catch {
    return; // sessionStorage unavailable (e.g. private browsing)
  }

  if (seen) {
    return;
  }

  const toggle = findSidebarToggleButton();
  const alreadyOpen =
    toggle?.getAttribute("aria-expanded") === "true" ||
    !!document.querySelector(".sidebar-hamburger-dropdown");

  if (toggle && !alreadyOpen) {
    toggle.click();
  }

  try {
    sessionStorage.setItem(seenKey, "1");
  } catch {
    // ignore
  }
}

// Sorts the Docs topic list A-Z, collating with the page's own <html lang>.
let docSortObservers = new Map();

function docSortLocale() {
  const lang = document.documentElement.lang;
  if (!lang) {
    return undefined;
  }

  try {
    Intl.getCanonicalLocales(lang); // throws RangeError on a malformed tag
    return lang;
  } catch {
    return undefined; // falls back to the browser's default locale
  }
}

function sortDocTopicList(body, locale) {
  const rows = [...body.querySelectorAll(":scope > .topic-list-item")];
  if (rows.length < 2) {
    return;
  }

  const sorted = [...rows].sort((a, b) => {
    const titleA = a.querySelector(".title")?.textContent.trim() ?? "";
    const titleB = b.querySelector(".title")?.textContent.trim() ?? "";
    return titleA.localeCompare(titleB, locale);
  });

  if (sorted.every((row, i) => rows[i] === row)) {
    return; // already sorted — stops the observer from feeding itself
  }

  // Insert before whatever follows the rows, keeping any load-more sentinel last.
  const anchor = rows[rows.length - 1].nextSibling;

  // Pin the first visible row so inserts above it don't jump the scroll.
  const pinned = rows.find((row) => row.getBoundingClientRect().bottom > 0);
  const pinnedTop = pinned?.getBoundingClientRect().top;

  // Observer paused so our own moves don't re-enter this function.
  const observer = docSortObservers.get(body);
  observer?.disconnect();
  sorted.forEach((row) => body.insertBefore(row, anchor));
  observer?.observe(body, { childList: true });

  if (pinned) {
    window.scrollBy(0, pinned.getBoundingClientRect().top - pinnedTop);
  }
}

function sortDocCategoryTopicLists() {
  docSortObservers.forEach((observer) => observer.disconnect());
  docSortObservers = new Map();

  const locale = docSortLocale();

  // Not a flex/grid container, so reordering must move DOM nodes — CSS `order` is ignored.
  document.querySelectorAll(".topic-list.doc-simple-mode .topic-list-body").forEach((body) => {
    // try/finally so the list is always revealed even if sorting throws.
    try {
      sortDocTopicList(body, locale);
    } finally {
      body.classList.add("docs-sorted");
    }

    // Sort only once loading goes quiet — mid-load reordering stalled the loader.
    let settleTimer = null;
    const observer = new MutationObserver(() => {
      window.clearTimeout(settleTimer);
      settleTimer = window.setTimeout(() => {
        sortDocTopicList(body, locale);
      }, 400);
    });
    observer.observe(body, { childList: true });
    docSortObservers.set(body, observer);
  });
}

// Mirrors core's DEFAULT_BINDINGS, minus ones intentionally left enabled or global.
const DISCOURSE_ONLY_SHORTCUTS = [
  "!", "#", "/", "=", "?", ".",
  "a", "b", "c", "shift+c",
  "command+left", "command+[", "command+right", "command+]",
  "d", "e", "end", "command+down", "f",
  "g h", "g l", "g n", "g u", "g y", "g c", "g t", "g b", "g p", "g m", "g d",
  "g s", "g j", "g k",
  "home", "command+up", "j", "k", "l",
  "m m", "m r", "m t", "m w",
  "tab", "p", "q", "r", "s",
  "shift+j", "shift+k", "shift+p", "shift+r", "shift+s", "shift+l",
  "shift+z shift+z", "shift+u", "shift+a", "shift+b",
  "t", "u", "x", "shift+d",
];

export default apiInitializer((api) => {

  if (settings.disable_discourse_keyboard_shortcuts) {
    api.container
      .lookup("service:keyboard-shortcuts")
      .pause(DISCOURSE_ONLY_SHORTCUTS);
  }

  // Replace some icons
  api.replaceIcon("discobot", "anonist");
  api.replaceIcon("far-discobot", "anonist");
  api.replaceIcon("language", "translate");
  api.replaceIcon("bars-staggered", "");
  api.replaceIcon("list", "ph-dt-list");
  api.replaceIcon("pencil", "ph-dt-pencil");
  api.replaceIcon("phone", "ph-dt-phone-list");

  // Do not display closed groups buttons
  const hideClosedButtons = () => {
    document.querySelectorAll(".group-membership-button").forEach((button) => {
      const text = button.textContent.trim().toLowerCase();
      if (text === "closed" || text === "cerrado") {
        button.style.display = "none";
      }
    });
  };

  api.onPageChange(() => {
    hideClosedButtons();
    // afterRender: onPageChange can fire before body classList updates.
    schedule("afterRender", () => {
      autoOpenDocSidebar();
      sortDocCategoryTopicLists();
    });
  });

  // Navigation not dropdown on mobile
  api.registerValueTransformer("navigation-bar-dropdown-mode", () => {
    return false;
  });

});