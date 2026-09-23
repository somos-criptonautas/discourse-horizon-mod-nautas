import { schedule } from "@ember/runloop";
import { apiInitializer } from "discourse/lib/api";
import { i18n } from "discourse-i18n";
import { themePrefix } from "virtual:theme";

// "Go back" on category and subcategory pages: up to the parent category, or to
// /categories from a top-level one.
//
// Derived from the path rather than the route model on purpose — category URLs are
// /c/<slug>/.../<id> with an optional filter suffix (/l/latest), so the numeric id
// marks where the slugs end.
export function parentPath(url) {
  const segments = (url || "").split("?")[0].split("/").filter(Boolean);

  if (segments[0] !== "c") {
    return null;
  }

  const idIndex = segments.findIndex((segment) => /^\d+$/.test(segment));
  if (idIndex < 2) {
    return null; // no id yet (or no slug before it): not a category page
  }

  const slugs = segments.slice(1, idIndex);
  return slugs.length > 1 ? `/c/${slugs.slice(0, -1).join("/")}` : "/categories";
}

// Placed by hand rather than through discovery-list-container-top, which renders
// BELOW .list-controls — the bar Horizon pins sticky (its scss/nav-pills.scss), so the
// link scrolled out of sight there. .navigation-container is inside that bar, and
// prepending puts the link ahead of the category/tag breadcrumbs.
//
// No outlet exists inside .list-controls, so this is a DOM insert on page change, same
// shape as translated-texts.gjs. Every miss leaves the page untouched.
const LINK_CLASS = "category-back-link";

function place() {
  const existing = document.querySelector(`.${LINK_CLASS}`);
  const href = parentPath(window.location.pathname);

  if (!href) {
    existing?.remove(); // left over from the category page we came from
    return;
  }

  const container = document.querySelector(
    ".list-controls .navigation-container"
  );
  if (!container) {
    existing?.remove();
    return;
  }

  // Already in place: only the target can have changed (subcategory → parent).
  if (existing && container.contains(existing)) {
    existing.setAttribute("href", href);
    return;
  }

  existing?.remove();

  const link = document.createElement("a");
  link.className = LINK_CLASS;
  link.setAttribute("href", href);
  // textContent, not innerHTML: the label is a translation string.
  link.textContent = i18n(themePrefix("category_back"));
  container.prepend(link);
}

export default apiInitializer((api) => {
  api.onPageChange(() => {
    // afterRender: onPageChange can fire before the new route's .list-controls is in
    // the DOM — the same reason init.gjs schedules its own DOM work.
    schedule("afterRender", place);
  });
});
