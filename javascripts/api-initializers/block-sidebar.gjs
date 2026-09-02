import { apiInitializer } from "discourse/lib/api";
import DiscourseURL from "discourse/lib/url";
import { i18n } from "discourse-i18n";

// Tiers come from the `blocked_sections` objects setting. Copy comes from
// locales/*.yml, keyed by each tier's `key`, so it stays translatable from
// Admin → Customize → Themes → this component → Edit translations.
// `themePrefix` is injected into theme JS automatically — do not import it.
const t = (key) => i18n(themePrefix(`blocked_sidebar.${key}`));

const splitPaths = (raw) =>
  (raw || "")
    .split(",")
    .map((p) => p.trim())
    .filter(Boolean);

// Custom sidebar links only expose the category id at the end of the href
// (/c/57). Link names are slugs — they change on rename and per language.
function categoryIdFrom(path) {
  const match = path.match(/\/(\d+)(?:\/l\/[a-z-]+)?\/?(?:\?|$)/);
  return match ? parseInt(match[1], 10) : null;
}

function matches(tier, path, categoryId) {
  if (categoryId && (tier.categories || []).includes(categoryId)) {
    return true;
  }
  return splitPaths(tier.paths).some((prefix) => path.startsWith(prefix));
}

function selectorsFor(tier) {
  const byCategory = (tier.categories || []).map(
    (id) => `.sidebar-section-link[href$="/${id}"]`
  );
  // Quoted attribute value: only backslashes and double quotes need escaping.
  const byPath = splitPaths(tier.paths).map((p) => {
    const safe = p.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
    return `.sidebar-section-link[href^="${safe}"]`;
  });
  return [...byCategory, ...byPath];
}

export default apiInitializer("1.8.0", (api) => {
  const tiers = settings.blocked_sections || [];
  const user = api.getCurrentUser();
  const myGroups = new Set((user?.groups || []).map((g) => g.id));

  // Anonymous visitors are in no group, so every tier applies to them.
  const locked = tiers.filter(
    (tier) => !(tier.allowed_groups || []).some((id) => myGroups.has(id))
  );

  if (locked.length === 0) {
    return;
  }

  // One <style> built from the same tier data the interceptor uses, so the
  // styling and the blocking can never drift apart.
  const css = locked
    .map((tier) => {
      const selectors = selectorsFor(tier).join(",\n");
      if (!selectors) {
        return "";
      }
      return tier.hide
        ? `${selectors} { display: none; }`
        : `${selectors} { cursor: help; opacity: 0.55; }`;
    })
    .filter(Boolean)
    .join("\n");

  if (css) {
    const existing = document.getElementById("blocked-sidebar-styles");
    const style = existing || document.createElement("style");
    style.id = "blocked-sidebar-styles";
    style.textContent = css;
    if (!existing) {
      document.head.append(style);
    }
  }

  const dialog = api.container.lookup("service:dialog");

  function openDialog(tier) {
    const scrollY = window.scrollY;
    let navigating = false;
    // dismiss first so it renders on the left, primary action on the right
    const buttons = [{ label: t("dismiss"), class: "btn-default" }];

    if (tier.cta_url) {
      buttons.push({
        label: t("cta"),
        icon: tier.cta_icon || "ph-dt-ticket",
        class: "btn-primary",
        action: () => {
          navigating = true;
          DiscourseURL.routeTo(tier.cta_url);
        },
      });
    }

    dialog
      .alert({
        title: t(`${tier.key}.title`),
        message: t(`${tier.key}.message`),
        class: "blocked-sidebar-dialog",
        buttons,
      })
      .then(() => {
        if (navigating) {
          return;
        }
        // a11y-dialog refocuses the trigger on close and the browser scrolls
        // to reveal it. Two frames puts us after that, so the restore sticks.
        requestAnimationFrame(() =>
          requestAnimationFrame(() => {
            if (window.scrollY !== scrollY) {
              window.scrollTo({ top: scrollY, behavior: "instant" });
            }
          })
        );
      });
  }

  // One delegated listener, capture phase, so it runs before Ember's router
  // and survives every sidebar re-render.
  const intercept = (event) => {
    const link = event.target.closest("a.sidebar-section-link");
    if (!link) {
      return;
    }

    const path = link.pathname + link.search;
    const categoryId = categoryIdFrom(path);
    const tier = locked.find((candidate) =>
      matches(candidate, path, categoryId)
    );

    if (!tier) {
      return;
    }

    event.preventDefault();
    event.stopPropagation();

    // a11y-dialog remembers document.activeElement and refocuses it on close;
    // blurring first means it restores to <body> instead of scrolling the
    // sidebar link back into view.
    link.blur();

    // auxclick fires for middle-click; no modal there, just don't open the tab
    if (event.type === "click" && !tier.hide) {
      openDialog(tier);
    }
  };

  document.addEventListener("click", intercept, true);
  document.addEventListener("auxclick", intercept, true);
});