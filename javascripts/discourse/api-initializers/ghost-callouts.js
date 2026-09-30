import { apiInitializer } from "discourse/lib/api";

// Ghost callout cards inside embedded blog topics are rewritten into the same
// `[!type]` blockquotes forum posts use, so the Quote Callouts component renders
// them: one look, one set of icons and labels, no second style to maintain.
//
// It happens in the `cooked` getter rather than a cooked decorator on purpose —
// the HTML is rewritten before any decorator runs, so this does not depend on
// which component's decorator registered first.
//
// Ghost's colours carry no meaning (the editor only offers a palette), so the
// mapping below is by hue and is the editorial convention, not a technical one.
// An unmapped colour, or a type this forum no longer defines, falls back to
// Quote Callouts' own `callout_fallback_type` — never a visible `[!type]`.
const CALLOUT_TYPE_BY_COLOR = {
  blue: "info",
  green: "success",
  yellow: "warning",
  red: "danger",
  pink: "danger",
  purple: "note",
  grey: "note",
  white: "quote",
  accent: "info",
};

// Ghost's emoji is dropped: the callout type carries its own icon, and keeping
// both reads as a duplicate.
function rewriteCard(card, doc) {
  const text = card.querySelector(".kg-callout-text");
  if (!text) {
    return;
  }

  const color = /\bkg-callout-card-([a-z]+)\b/.exec(card.className)?.[1];
  const type = CALLOUT_TYPE_BY_COLOR[color] ?? "note";

  const marker = doc.createElement("p");
  marker.textContent = `[!${type}]`;

  const body = doc.createElement("p");
  body.append(...text.childNodes);

  const blockquote = doc.createElement("blockquote");
  blockquote.append(marker, body);
  card.replaceWith(blockquote);
}

export default apiInitializer((api) => {
  api.modifyClass("component:post/cooked-html", (Superclass) => {
    return class extends Superclass {
      get cooked() {
        const value = super.cooked;
        // `value` may be a TrustedHTML wrapper; the template re-wraps a string.
        const html = value?.toString();

        if (!html?.includes("kg-callout-card")) {
          return value;
        }

        // DOMParser keeps the fragment inert — nothing loads or runs while the
        // nodes are moved around, and the markup was already sanitized server-side.
        const doc = new DOMParser().parseFromString(html, "text/html");
        doc
          .querySelectorAll(".kg-callout-card")
          .forEach((card) => rewriteCard(card, doc));

        return doc.body.innerHTML;
      }
    };
  });
});
