import { apiInitializer } from "discourse/lib/api";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";
import { themePrefix } from "virtual:theme";

const CLASS = "fk-d-menu__monthly-karma";
const USER_INFO = ".custom-user-menu-content .fk-d-menu__user-info";

export default apiInitializer((api) => {
  if (!api.getCurrentUser()) {
    return;
  }

  // Monthly cheer points from the leaderboard. A valid response with an empty
  // `personal` means no points yet this month, so that reads as 0; anything else
  // that lacks `users` is not a leaderboard and the line is dropped.
  // One successful request per page load: the menu gets opened over and over.
  let scoreRequest;
  function monthlyScore() {
    scoreRequest ||= ajax("/leaderboard", { data: { period: "monthly" } })
      .then((json) =>
        json?.users ? (json.personal?.user?.total_score ?? 0) : null
      )
      .catch(() => {
        scoreRequest = null; // let the next open retry
        return null;
      });
    return scoreRequest;
  }

  async function decorate(userInfo) {
    if (userInfo.querySelector(`.${CLASS}`)) {
      return;
    }

    const line = document.createElement("span");
    line.className = CLASS;
    userInfo.append(line);

    const score = await monthlyScore();

    if (!line.isConnected) {
      return; // menu was closed while the request was in flight
    }

    if (score === null) {
      line.remove();
      return;
    }

    const label = document.createElement("strong");
    label.textContent = i18n(themePrefix("monthly_karma"));
    const value = document.createElement("span");
    value.textContent = score.toLocaleString();
    line.replaceChildren(label, value);
  }

  // The custom-user-menu component exposes no plugin outlet and float-kit
  // teleports its content into a portal on open, so watch for it to appear
  // rather than hooking the trigger's click, which float-kit may swallow.
  new MutationObserver(() => {
    const userInfo = document.querySelector(USER_INFO);
    if (userInfo) {
      decorate(userInfo);
    }
  }).observe(document.body, { childList: true, subtree: true });
});
