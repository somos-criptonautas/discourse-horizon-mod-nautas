import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
  api.modifyClass(
    "controller:discovery/categories",
    (Superclass) =>
      class extends Superclass {
        get categoryPageStyle() {
          return this.siteSettings.desktop_category_page_style;
        }
      }
  );
});