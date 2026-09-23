import { apiInitializer } from "discourse/lib/api";

// Several bot accounts are one persona to readers. This rewrites the visible
// label only — hrefs, quote attributions, markdown mentions, search, emails and
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

// Poster lines and user-card triggers carry the username in data-user-card;
// a mention carries it in the href. Exported shape kept tiny on purpose.
export function usernameOf(link) {
  return (
    link.dataset.userCard ||
    link.getAttribute("href")?.match(/^\/u\/([^/?#]+)/)?.[1] ||
    null
  );
}

function relabel(link) {
  // Never touch a link that wraps markup: avatar anchors carry the same
  // data-user-card, and writing textContent would delete the <img>.
  if (link.children.length > 0) {
    return;
  }

  const username = usernameOf(link);
  if (!username) {
    return;
  }

  const label = BOT_LABELS[username.toLowerCase()];
  if (!label) {
    return;
  }

  // Only a bare username is replaced, so a link whose text is something else
  // ("view profile", a display name already set server-side) is left alone.
  const text = link.textContent.trim();
  const mention = text.startsWith("@");
  if (text.replace(/^@/, "").toLowerCase() !== username.toLowerCase()) {
    return;
  }

  // textContent, never innerHTML: the value comes from the map above, and this
  // cannot introduce markup even if a username ever contained some.
  link.textContent = mention ? `@${label}` : label;
}

export default apiInitializer((api) => {
  // onPageChange only, no MutationObserver: a post rendered later (or re-rendered
  // by Glimmer) shows the real username until the next navigation. That is the
  // honest degradation — the alternative is fighting Ember over text nodes.
  api.onPageChange(() => {
    document
      .querySelectorAll("a[data-user-card], a.mention")
      .forEach(relabel);
  });
});
