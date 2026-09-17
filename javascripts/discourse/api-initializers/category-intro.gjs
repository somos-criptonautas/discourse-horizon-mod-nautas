import { apiInitializer } from "discourse/lib/api";
import { i18n } from "discourse-i18n";

// Localize the category banner titles and descriptions rendered from
// after_header.html. Each banner wrapper class maps to a key in
// locales/*.yml so the copy is translatable from Admin → Customize → Themes
// → this component → Edit translations. `themePrefix` is injected into
// theme JS automatically — do not import it.
const t = (key) => i18n(themePrefix(`category_intros.${key}`));

const BANNER_CLASS_TO_KEY = {
  "category-banner-groups": "ghettos",
  "category-banner-badges": "retos",
  "category-banner-leaderboard": "karma",
  "category-banner-guidelines": "costumbres",
};

export default apiInitializer((api) => {
  api.onPageChange(() => {
    for (const [className, key] of Object.entries(BANNER_CLASS_TO_KEY)) {
      const banner = document.querySelector(
        `.custom-page-intro.${className}`
      );
      if (!banner) {
        continue;
      }

      const title = banner.querySelector(
        ".category-title .badge-category__name"
      );
      if (title) {
        title.textContent = t(`${key}.title`);
      }

      const desc = banner.querySelector(
        ".category-title-description .cooked > div"
      );
      if (desc) {
        desc.textContent = t(`${key}.description`);
      }
    }
  });
});
