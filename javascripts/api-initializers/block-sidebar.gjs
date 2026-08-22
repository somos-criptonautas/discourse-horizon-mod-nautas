import { apiInitializer } from "discourse/lib/api";
import { i18n } from "discourse-i18n";

// Copy lives in locales/*.yml and is editable per-locale from
// Admin → Customize → Themes → this component → Edit translations.
// `themePrefix` is injected into theme JS automatically — do not import it.
function modalFor(group) {
  return {
    title: i18n(themePrefix(`blocked_sidebar.${group}.title`)),
    message: i18n(themePrefix(`blocked_sidebar.${group}.message`)),
  };
}

// ---- WHAT EACH GROUP UNLOCKS -------------------------------------------
const RULES = {
  tl2: {
    categoryIds: [57], // feedback
    paths: [],
  },
  tl3: {
    categoryIds: [64, 5, 59], // en la mira, analisis, eventos
    paths: ["/upcoming-events", "/resenha/r/lounge"],
  },
};
// -------------------------------------------------------------------------

// These are custom sidebar links, so the only stable identifier is the id at
// the end of the href (/c/57). Link names are slugs — they change on rename
// and differ per language.
function categoryIdFrom(path) {
  const match = path.match(/\/(\d+)(?:\/l\/[a-z-]+)?\/?(?:\?|$)/);
  return match ? parseInt(match[1], 10) : null;
}

function isBlocked(rule, path, categoryId) {
  if (categoryId && rule.categoryIds.includes(categoryId)) {
    return true;
  }
  return rule.paths.some((prefix) => path.startsWith(prefix));
}

export default apiInitializer("1.8.0", (api) => {
  const user = api.getCurrentUser();
  const groups = user?.groups?.map((g) => g.name) || [];
  const missing = Object.keys(RULES).filter((name) => !groups.includes(name));

  if (missing.length === 0) {
    return;
  }

  // Drives the CSS. Anonymous visitors get both classes.
  missing.forEach((name) => document.body.classList.add(`no-${name}`));

  const dialog = api.container.lookup("service:dialog");

  // One delegated listener, capture phase, so it runs before Ember's router
  // and survives every sidebar re-render.
  const intercept = (event) => {
    const link = event.target.closest("a.sidebar-section-link");
    if (!link) {
      return;
    }

    const path = link.pathname + link.search;
    const categoryId = categoryIdFrom(path);
    const hit = missing.find((name) =>
      isBlocked(RULES[name], path, categoryId)
    );

    if (!hit) {
      return;
    }

    event.preventDefault();
    event.stopPropagation();

    // auxclick fires for middle-click; no modal there, just don't open the tab
    if (event.type === "click") {
      dialog.alert(modalFor(hit));
    }
  };

  document.addEventListener("click", intercept, true);
  document.addEventListener("auxclick", intercept, true);
});