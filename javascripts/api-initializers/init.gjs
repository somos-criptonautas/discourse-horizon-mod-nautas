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

// A-Z needs the whole category: core cannot order a topic list by title
// (TopicQuery::SORTABLE_MAPPING has no "title"), so we exhaust the paginated list
// before sorting. Capped — docs categories are small; anything bigger falls back to
// sorting whatever is loaded, which the MutationObserver below keeps up to date.
// ponytail: drop this whole loop if core ever ships server-side title ordering.
const MAX_DOC_PAGES = 12; // ~360 topics at 30 per page
let docLoadRun = 0;

async function loadAllDocTopics(api) {
  const run = ++docLoadRun;

  // Semi-private: the discovery controller has been refactored before. Failing here
  // just means we sort the first page, so every step is optional-chained.
  const list = api.container.lookup("controller:discovery/topics")?.model;
  if (!list?.loadMore) {
    return;
  }

  for (let page = 0; page < MAX_DOC_PAGES; page++) {
    if (!list.more_topics_url) {
      return;
    }

    const before = list.topics?.length ?? 0;
    await list.loadMore();

    // Navigated away mid-load, or the list stopped growing — either way, stop.
    if (run !== docLoadRun || (list.topics?.length ?? 0) === before) {
      return;
    }
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
  api.replaceIcon("discobot", "ph-dt-anonist");
  api.replaceIcon("far-discobot", "ph-dt-anonist");

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

      if (!document.querySelector(".topic-list.doc-simple-mode")) {
        return;
      }

      // Sort once the category is fully loaded; finally() so a failed or capped
      // load still gets the first page sorted and revealed.
      loadAllDocTopics(api)
        .catch(() => {}) // a failed page load is not a reason to leave the list hidden
        .finally(() => schedule("afterRender", sortDocCategoryTopicLists));
    });
  });

  // Navigation not dropdown on mobile
  api.registerValueTransformer("navigation-bar-dropdown-mode", () => {
    return false;
  });

  // Add leaderboard page CSS body class
  api.onPageChange((url) => {
  const isLeaderboard = url.startsWith("/leaderboard");
  document.body.classList.toggle("leaderboard-page", isLeaderboard);
  });

});