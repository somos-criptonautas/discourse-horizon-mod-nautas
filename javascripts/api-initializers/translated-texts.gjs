import { i18n } from "discourse-i18n";
import { themePrefix } from "virtual:theme";
import apiInitializer from "discourse/lib/api-initializer";

export default apiInitializer("0.11.1", (api) => {
  api.onPageChange(() => {
    const podium = document.querySelector(".podium__wrapper");
    if (!podium || podium.querySelector(".podium-note")) {
      return;
    }
    const note = document.createElement("div");
    note.className = "podium-note";
    note.textContent = i18n(themePrefix("podium_note"));
    podium.appendChild(note);
  });
});