import Component from "@glimmer/component";
import { service } from "@ember/service";
import { apiInitializer } from "discourse/lib/api";
import { i18n } from "discourse-i18n";

// "Go back" above the topic list on category and subcategory pages: up to the
// parent category, or to /categories from a top-level one.
//
// Derived from the path rather than the route model on purpose — category URLs
// are /c/<slug>/.../<id> with an optional filter suffix (/l/latest), so the
// numeric id marks where the slugs end. Only the public router service is
// touched, so no core internals to keep up with.
function parentPath(url) {
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

class CategoryBackLink extends Component {
  @service router;

  get href() {
    return parentPath(this.router.currentURL);
  }

  // `themePrefix` is injected into theme JS automatically — it is not a
  // template helper, so the label is built here.
  get label() {
    return i18n(themePrefix("category_back"));
  }

  <template>
    {{#if this.href}}
      <a class="category-back-link" href={{this.href}}>{{this.label}}</a>
    {{/if}}
  </template>
}

export default apiInitializer((api) => {
  api.renderInOutlet("discovery-list-container-top", CategoryBackLink);
});
