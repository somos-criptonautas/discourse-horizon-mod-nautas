import { schedule } from "@ember/runloop";
import { apiInitializer } from "discourse/lib/api";

// Several bot accounts are one persona to readers. This rewrites the visible label
// only — hrefs, quote attributions, markdown mentions, search queries, emails and
// anything copied out keep the real username, which is also what makes it safe:
// nothing here changes identity, permissions or where a link points.
//
// Keys are real usernames (lowercase), values what the reader sees. Site-specific
// like DOC_CATEGORY_SLUGS in init.gjs — a new bot needs a line here.
const BOT_LABELS = {
  anonist_mcp: "anonist",
  anonist_links: "anonist",
  anonist_qa: "anonist",
};

// Where core prints a username. Links carry it in data-user-card or the href; the rest
// are plain spans, which is why the earlier link-only pass missed most of them:
//   .username          d-user-info, search results and menus, reviewables, PM map,
//                      autocomplete, group requests
//   .name              post-list items, search results (falls back to the username
//                      when the account has no full name)
//   .user-profile-names__secondary   the username under a profile's heading
//   .users-popup__username           the "who liked this" popup
// Nothing is rewritten unless the element's own text IS the username, so a element
// holding anything else is left alone.
const LABEL_SELECTORS = [
  "a[data-user-card]",
  "a.mention",
  ".username",
  ".name",
  ".user-profile-names__secondary",
  ".users-popup__username",
].join(",");

// Poster lines and user-card triggers carry the username in data-user-card; a mention
// carries it in the href. Plain spans carry it only as their text.
function usernameOf(element) {
  return (
    element.dataset.userCard ||
    element.getAttribute("href")?.match(/^\/u\/([^/?#]+)/)?.[1] ||
    element.textContent.trim().replace(/^@/, "") ||
    null
  );
}

function relabel(element) {
  // Never touch an element that wraps markup: avatar anchors carry the same
  // data-user-card, and writing textContent would delete the <img>.
  if (element.children.length > 0) {
    return;
  }

  const username = usernameOf(element);
  if (!username) {
    return;
  }

  const label = BOT_LABELS[username.toLowerCase()];
  if (!label) {
    return;
  }

  // Only a bare username is replaced, so an element whose text is something else
  // ("view profile", a display name already set server-side, an already-relabelled
  // node) is left alone — which also makes repeated passes idempotent.
  const text = element.textContent.trim();
  const mention = text.startsWith("@");
  if (text.replace(/^@/, "").toLowerCase() !== username.toLowerCase()) {
    return;
  }

  // textContent, never innerHTML: the value comes from the map above, and this cannot
  // introduce markup even if a username ever contained some.
  element.textContent = mention ? `@${label}` : label;
}

// A bot is not someone you message. Core uses .compose-pm for that button in both
// places it appears: li.compose-pm in the user card, .btn-primary.compose-pm on the
// profile page.
function hidePrivateMessageButtons() {
  const onBotProfile = Object.keys(BOT_LABELS).some((username) =>
    window.location.pathname.toLowerCase().startsWith(`/u/${username}`)
  );

  if (onBotProfile) {
    document
      .querySelectorAll(".user-content .compose-pm, .user-profile .compose-pm")
      .forEach((element) => (element.hidden = true));
  }

  // The card is one user at a time: its own username line says whose it is.
  document.querySelectorAll(".user-card").forEach((card) => {
    const name = card
      .querySelector(".username, .user-profile-names__secondary")
      ?.textContent.trim()
      .replace(/^@/, "")
      .toLowerCase();

    // Already relabelled to the shared name, or still the raw username: both mean bot.
    const isBot =
      !!BOT_LABELS[name] || Object.values(BOT_LABELS).includes(name);

    if (isBot) {
      card
        .querySelectorAll(".compose-pm")
        .forEach((element) => (element.hidden = true));
    }
  });
}

function pass() {
  document.querySelectorAll(LABEL_SELECTORS).forEach(relabel);
  hidePrivateMessageButtons();
}

export default apiInitializer((api) => {
  api.onPageChange(() => schedule("afterRender", pass));

  // User cards, menus and popups open without a route change, so a page-change pass
  // alone never sees them. One delegated listener re-runs on the frame after any
  // click, which is when float-kit has put the card in the DOM. Cheap: the pass is
  // two querySelectorAll calls and exits on the first mismatch per element.
  document.addEventListener(
    "click",
    () => requestAnimationFrame(() => requestAnimationFrame(pass)),
    { passive: true }
  );
});
