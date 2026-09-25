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

function isBox(node) {
  return (
    node.nodeType === Node.ELEMENT_NODE &&
    (node.classList.contains("chcklst-box") ||
      !!node.querySelector?.(".chcklst-box"))
  );
}

// A "line" is what sits between two <br>s (or the block's edges): the plugin puts every
// item of an inline checklist in one paragraph separated by breaks.
function lineNodes(box, direction) {
  const nodes = [];
  let node = direction === "forward" ? box.nextSibling : box.previousSibling;

  while (node && node.nodeName !== "BR") {
    nodes.push(node);
    node = direction === "forward" ? node.nextSibling : node.previousSibling;
  }

  return nodes;
}

function strikeLabel(box) {
  // Already wrapped (a second pass would nest wrappers).
  if (
    box.nextSibling?.nodeType === Node.ELEMENT_NODE &&
    box.nextSibling.classList.contains(STROKE_CLASS)
  ) {
    return;
  }

  const after = lineNodes(box, "forward");

  // Leave the line alone when it carries another checkbox, before or after this one:
  // the label of one box cannot be told apart from the label of the next, so striking
  // would cross out text that belongs to a different item.
  if (after.some(isBox) || lineNodes(box, "backward").some(isBox)) {
    return;
  }

  const wrapper = document.createElement("span");
  wrapper.className = STROKE_CLASS;

  for (const node of after) {
    wrapper.append(node); // moves the existing node, never re-parses HTML
  }

  if (wrapper.childNodes.length === 0) {
    return;
  }

  box.after(wrapper);

  // The strike starts at the label, not at the space that follows the box — otherwise
  // the line reads as crossing the box itself. Leading whitespace is moved back out,
  // in front of the wrapper.
  while (wrapper.firstChild?.nodeType === Node.TEXT_NODE) {
    const text = wrapper.firstChild;
    const spaces = text.data.length - text.data.trimStart().length;

    if (spaces === 0) {
      break;
    }

    if (spaces < text.data.length) {
      // splitText keeps the spaces in `text` and leaves the label in a new sibling
      // inside the wrapper, so only `text` has to move out.
      text.splitText(spaces);
      wrapper.before(text);
      break;
    }

    // Whitespace-only node: move it out, then look at the next one.
    wrapper.before(text);
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
