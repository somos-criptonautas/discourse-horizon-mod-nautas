// {theme}/javascripts/discourse/api-initializers/init-theme.gjs
import { apiInitializer } from "discourse/lib/api";
import { schedule } from "@ember/runloop";

function cleanGroupNames() {
  document.querySelectorAll(".group-info-name").forEach((el) => {
    el.childNodes.forEach((node) => {
      if (node.nodeType === Node.TEXT_NODE) {
        node.textContent = node.textContent.replace(/\[.*?\]/g, "").trim();
      }
    });
  });
}

// Categories rendered by the Discourse Docs plugin. Detected two ways at
// once (either is enough) since neither has been confirmed against live
// markup: the plugin's own sidebar panel being present, OR the known
// category slugs. Shared by the auto-open-sidebar behavior below and the
// alphabetical sort further down — the plugin has no native title sort
// (confirmed: no such setting exists, and Discourse core doesn't index
// topics by title either), so it's done client-side here instead of
// forking the plugin or a separate component.
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

// #toggle-hamburger-menu confirmed from actual live markup (the button
// inside <li class="header-dropdown-toggle hamburger-dropdown">, title
// "Menú principal (categorías, mensajes, ajustes)") — .btn-sidebar-toggle
// and .header-sidebar-toggle, used everywhere else in this theme
// (including by the original pre-existing code), don't exist at all; kept
// below only as harmless fallbacks in case some other page state uses them.
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

function autoOpenDocSidebar() {
  if (!window.matchMedia("(max-width: 576px)").matches) {
    return;
  }

  if (!isDocCategoryPage()) {
    return;
  }

  let seen;
  try {
    seen = sessionStorage.getItem(DOC_SIDEBAR_SEEN_KEY);
  } catch {
    return; // sessionStorage unavailable (e.g. private browsing)
  }

  if (seen) {
    document.body.classList.add("sidebar-toggle-seen");
    return;
  }

  const toggle = findSidebarToggleButton();
  const alreadyOpen =
    toggle?.getAttribute("aria-expanded") === "true" ||
    !!document.querySelector(".sidebar-hamburger-dropdown");

  if (toggle && !alreadyOpen) {
    toggle.click();
  }

  document.body.classList.add("sidebar-toggle-seen");
  try {
    sessionStorage.setItem(DOC_SIDEBAR_SEEN_KEY, "1");
  } catch {
    // ignore
  }
}

// Alphabetically sort the Docs plugin's topic list (glosario/wiki/trading-curso).
// Re-runs on every page change and watches each list for further row
// insertions (pagination/infinite scroll), so newly-loaded topics land in
// the right spot without any manual pinning/reordering.
//
// Locale: uses the page's own <html lang> instead of a hardcoded language,
// so collation (accents, ñ, ç, etc.) is correct for whatever locale the
// page is actually rendered in — Spanish today, Portuguese/English/others
// later, with no per-language code changes needed.
let docSortObservers = [];

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
    return; // already sorted — also breaks the observer's own feedback loop
  }

  // Move only the rows that are actually out of place, one at a time —
  // not a detach-everything-into-a-fragment-then-reappend. The fragment
  // approach briefly removes every row from `body` in the same pass,
  // which (with infinite scroll appending a load-more sentinel right
  // after this list) was very likely shifting that sentinel enough to
  // keep re-triggering "load more", i.e. the infinite-loading-forever
  // symptom. This keeps rows continuously attached and only touches the
  // ones that need to move.
  sorted.forEach((row, index) => {
    if (body.children[index] !== row) {
      body.insertBefore(row, body.children[index] ?? null);
    }
  });
}

function sortDocCategoryTopicLists() {
  docSortObservers.forEach((observer) => observer.disconnect());
  docSortObservers = [];

  const locale = docSortLocale();

  // .topic-list-body, not tbody/tr — Discourse's topic list moved off
  // table markup to Glimmer components; topic-list-body/topic-list-item
  // are the stable classes it kept specifically so selectors like this
  // wouldn't break across that migration.
  document.querySelectorAll(".topic-list.doc-simple-mode .topic-list-body").forEach((body) => {
    // try/finally so the list is always revealed (see the .docs-sorted CSS
    // hook in main.scss) even if sorting itself throws for some reason.
    try {
      sortDocTopicList(body, locale);
    } finally {
      body.classList.add("docs-sorted");
    }

    // Coalesced via rAF, not a setTimeout debounce: a fixed delay (tried
    // 120ms) meant that during continuous infinite-scroll loading, mutations
    // kept arriving faster than the delay, so the timer kept resetting and
    // the list only ever looked sorted once scrolling fully stopped. Instead,
    // schedule at most one resort per animation frame — it still coalesces
    // multiple mutations landing in the same tick, but resolves right before
    // the next paint instead of after an arbitrary wait, so each newly
    // loaded batch gets sorted essentially immediately rather than only at
    // the very end.
    let rafId = null;
    const observer = new MutationObserver(() => {
      if (rafId !== null) {
        return;
      }
      rafId = window.requestAnimationFrame(() => {
        rafId = null;
        sortDocTopicList(body, locale);
      });
    });
    observer.observe(body, { childList: true });
    docSortObservers.push(observer);
  });
}

// Hide the secondary nav on mobile for the user activity/invites/billing
// pages. The existing CSS rules (new-user.scss/main.scss,
// body.user-activity-page etc. .user-navigation-secondary, !important)
// weren't taking effect, and the exact selector chain couldn't be
// confirmed against current Discourse core/Horizon markup remotely. This
// targets the same element directly by its own stable class and gates on
// the URL instead of a guessed body class, as a more robust backup
// alongside the existing CSS.
function hideActivitySecondaryNavOnMobile() {
  if (!window.matchMedia("(max-width: 576px)").matches) {
    return;
  }

  if (!/^\/u\/[^/]+\/(activity|invited|billing)/.test(window.location.pathname)) {
    return;
  }

  document.querySelectorAll(".user-navigation-secondary").forEach((el) => {
    el.style.display = "none";
  });
}

export default apiInitializer((api) => {

  // Replace some icons
  api.replaceIcon("robot", "lightning");
  api.replaceIcon("language", "translate");
  api.replaceIcon("pencil", "note-pencil");

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
    // Deferred to afterRender: onPageChange can fire before Ember has
    // finished updating document.body's classList for the new route, so
    // checking for category-* classes immediately was racy.
    schedule("afterRender", () => {
      autoOpenDocSidebar();
      sortDocCategoryTopicLists();
      hideActivitySecondaryNavOnMobile();
    });
  });

  // Navigation not dropdown on mobile
  api.registerValueTransformer("navigation-bar-dropdown-mode", () => {
    return false;
  });

  // Clean [XX] from group names on /g and /g/groupname
  const router = api.container.lookup("router:main");
  router.on("routeDidChange", () => {
    const url = router.currentURL;
    if (!url?.startsWith("/g")) return;
    schedule("afterRender", cleanGroupNames);
  });

});