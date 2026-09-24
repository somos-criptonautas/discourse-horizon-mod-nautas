import { apiInitializer } from "discourse/lib/api";
import { ajax } from "discourse/lib/ajax";
import { i18n } from "discourse-i18n";
import { themePrefix } from "virtual:theme";

const CLASS = "fk-d-menu__total-karma";

// The custom-user-menu component exposes no plugin outlet, and its content is
// teleported into a float-kit portal only after the avatar is clicked — so the
// line is appended on open instead of rendered. Bail after a few frames rather
// than observing the document for the lifetime of the page.
const MAX_FRAMES = 40;

export default apiInitializer((api) => {
  if (!api.getCurrentUser()) {
    return;
  }

  // Total cheer points, read from the user card — the only place gamification
  // serializes it: discourse-gamification's plugin.rb does
  // `add_to_serializer(:user_card, :gamification_score)` and nothing adds it to the
  // current-user payload. The previous version asked /leaderboard for a monthly
  // figure, got a shape it could not read, and silently removed its own line.
  //
  // One request per page load: the score barely moves and the menu gets opened over
  // and over.
  let scoreRequest;
  function totalScore() {
    const username = api.getCurrentUser()?.username;
    if (!username) {
      return Promise.resolve(null);
    }

    scoreRequest ||= ajax(`/u/${encodeURIComponent(username)}/card.json`)
      .then((json) => json?.user?.gamification_score ?? null)
      .catch(() => null);
    return scoreRequest;
  }

  async function decorate(userInfo) {
    if (userInfo.querySelector(`.${CLASS}`)) {
      return;
    }

    const line = document.createElement("span");
    line.className = CLASS;
    userInfo.append(line);

    const score = await totalScore();

    if (!line.isConnected) {
      return; // menu was closed while the request was in flight
    }

    // gamification may be absent, or the leaderboard hidden to this user:
    // drop the line rather than claim a score of zero.
    if (score === null || score === undefined) {
      line.remove();
      return;
    }

    line.textContent = i18n(themePrefix("total_karma"), {
      score: score.toLocaleString(),
    });
  }

  function waitForMenu(frames = 0) {
    const userInfo = document.querySelector(
      ".custom-user-menu-content .fk-d-menu__user-info"
    );

    if (userInfo) {
      decorate(userInfo);
      return;
    }

    if (frames < MAX_FRAMES) {
      requestAnimationFrame(() => waitForMenu(frames + 1));
    }
  }

  // Covers keyboard activation too, which also fires a click.
  document.addEventListener("click", (event) => {
    if (event.target.closest?.(".custom-user-menu")) {
      waitForMenu();
    }
  });
});
