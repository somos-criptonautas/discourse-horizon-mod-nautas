import { apiInitializer } from "discourse/lib/api";

// The blog embeds the full app (fullApp: true) as its comments section, and the
// embed should carry the conversation only: poster, content, and reply / like /
// flag. Everything else stays on the forum. Hidden notices, time gaps, footer
// buttons and suggested topics are in scss/main.scss (Embed comments).
//
// body.embed-mode is set by core in that mode - the same hook main.scss uses.
function isEmbed() {
  return document.body.classList.contains("embed-mode");
}

export default apiInitializer((api) => {
  // A whitelist rather than removing known keys: plugins (discourse-ai, solved,
  // reactions...) add their own buttons under names no blocklist can predict.
  // The transformer is mutable - the DAG is edited in place, and entries() is a
  // snapshot, so deleting while looping is safe.
  //
  // Theme initializers run after plugin ones, so plugin buttons are already in
  // the DAG by the time this prunes it.
  api.registerValueTransformer(
    "post-menu-buttons",
    ({ value: dag, context: { buttonKeys, collapsedButtons } }) => {
      if (!isEmbed()) {
        return;
      }

      const keep = [buttonKeys.REPLY, buttonKeys.LIKE, buttonKeys.FLAG];
      for (const [key] of dag.entries()) {
        if (!keep.includes(key)) {
          dag.delete(key);
        }
      }

      // Flag normally sits behind "...", which was just removed with the rest.
      collapsedButtons.show(buttonKeys.FLAG);
    }
  );

  api.registerValueTransformer("post-show-topic-map", ({ value }) =>
    isEmbed() ? false : value
  );
});
