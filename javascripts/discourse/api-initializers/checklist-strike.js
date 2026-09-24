import { schedule } from "@ember/runloop";
import { apiInitializer } from "discourse/lib/api";

// Strike the label of a ticked inline checkbox ([x] from core's checklist plugin).
//
// Why JS: the plugin renders the box as <span class="chcklst-box checked fa ..."> and
// leaves the label as plain sibling text in the same paragraph, one line per <br>. CSS
// cannot select a text node, nor scope a decoration to the run between two <br>s — a
// `p:has(.chcklst-box.checked)` rule strikes every line in the paragraph instead.
//
// The style is core's own: plugins/checklist/assets/stylesheets/checklist.scss defines
// span.chcklst-stroked { text-decoration: line-through } and the markdown allowlist
// already permits that class, so this only has to wrap the label in it.
//
// Unticking re-cooks the post, which rebuilds the paragraph and drops the wrapper.
const STROKE_CLASS = "chcklst-stroked";

// The label ends at the next line break, the next checkbox, or the end of the block.
function endsLine(node) {
  return (
    node.nodeName === "BR" ||
    (node.nodeType === Node.ELEMENT_NODE &&
      node.classList.contains("chcklst-box"))
  );
}

function strikeLabel(box) {
  // Already wrapped (a second decoration pass would nest wrappers).
  if (box.nextSibling?.nodeType === Node.ELEMENT_NODE &&
      box.nextSibling.classList.contains(STROKE_CLASS)) {
    return;
  }

  const wrapper = document.createElement("span");
  wrapper.className = STROKE_CLASS;

  let node = box.nextSibling;
  while (node && !endsLine(node)) {
    const next = node.nextSibling;
    wrapper.append(node); // moves the existing node, never re-parses HTML
    node = next;
  }

  if (wrapper.childNodes.length > 0) {
    box.after(wrapper);
  }
}

export default apiInitializer((api) => {
  // onPageChange over the rendered post, not decorateCookedElement: the decorator
  // never fired here (a ticked box stayed unwrapped in the DOM), and this is the
  // pattern the rest of this theme already relies on. strikeLabel() skips boxes it has
  // already wrapped, so running it again on the same posts costs a querySelectorAll.
  api.onPageChange(() => {
    schedule("afterRender", () => {
      document
        .querySelectorAll(".cooked .chcklst-box.checked")
        .forEach(strikeLabel);
    });
  });
});
