import { schedule } from "@ember/runloop";
import { apiInitializer } from "discourse/lib/api";

// "Borradores" belongs on the first thing someone sees on their profile, not buried in
// the activity section. CSS cannot do it: the two lists are separate <ul>s, and `order`
// only reorders siblings.
//
// The link is CLONED rather than moved. Moving it would pull a node out of the tree
// Glimmer renders for the activity section, which it may put back (or trip over) on its
// next render; a clone is ours, so the original list stays untouched — it is only hidden,
// in scss/user.scss. The clone is a plain <a href>, and Discourse routes internal links
// by href, so navigation still happens client-side.
//
// Ids are stripped from the copy: core renders ember ids on those anchors and two
// elements with the same id in one document is invalid.
const SOURCE = '[data-list-item-name="user-nav-activity-drafts"]';
const TARGET = "#sidebar-section-content-user-nav-profile";
const CLONE_CLASS = "horizon-profile-drafts";

function place() {
  const target = document.querySelector(TARGET);
  if (!target) {
    return;
  }

  const source = document.querySelector(
    `#sidebar-section-content-user-nav-activity ${SOURCE}`
  );
  if (!source) {
    return; // no drafts entry for this user
  }

  // Replaced rather than skipped: the entry carries the draft count, so a stale copy
  // would keep showing the number from whenever it was first cloned.
  target.querySelector(`.${CLONE_CLASS}`)?.remove();

  const clone = source.cloneNode(true);
  clone.classList.add(CLONE_CLASS);
  clone.removeAttribute("id");
  clone.querySelectorAll("[id]").forEach((node) => node.removeAttribute("id"));

  target.append(clone);
}

export default apiInitializer((api) => {
  // afterRender, like the rest of this theme's DOM work: onPageChange can fire before
  // the panel for the new route exists.
  api.onPageChange(() => schedule("afterRender", place));
});
