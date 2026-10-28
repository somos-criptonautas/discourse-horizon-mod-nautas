import { schedule } from "@ember/runloop";
import { themePrefix } from "virtual:theme";
import { apiInitializer } from "discourse/lib/api";
import { iconHTML } from "discourse/lib/icon-library";
import { i18n } from "discourse-i18n";

// Fullscreen button for discourse-chart, the same affordance Pele gives diagrams.
//
// The plugin draws on a <canvas> at the post's width with Chart.js' 12px labels and
// offers no way to enlarge it. Moving the live chart into a bigger box would only
// re-render it wider with the same 12px text, so instead the canvas bitmap is shown as
// an image scaled to the viewport: labels grow with it. Chart.js draws at
// devicePixelRatio, so on most screens the bitmap is ~2x the displayed size and stays
// sharp when enlarged.
//
// onPageChange + afterRender rather than decorateCookedElement: the pattern the rest
// of this theme relies on (see checklist-strike.js). addButton() skips charts it has
// already wrapped, so re-running costs a querySelectorAll. The canvas is read at click
// time because the plugin renders it asynchronously, after the cooked HTML is in place.
const CHART_SELECTOR = ".cooked .discourse-chart";
const HOST_CLASS = "chart-fullscreen-host";

function label(key) {
  return i18n(themePrefix(`chart_fullscreen.${key}`));
}

function openOverlay(canvas, title) {
  const overlay = document.createElement("div");
  overlay.className = "chart-fullscreen";
  overlay.setAttribute("role", "dialog");
  overlay.setAttribute("aria-modal", "true");
  overlay.setAttribute("aria-label", title);

  const image = document.createElement("img");
  image.className = "chart-fullscreen__image";
  image.src = canvas.toDataURL("image/png");
  image.alt = title;

  const close = document.createElement("button");
  close.type = "button";
  close.className = "btn btn-flat btn-icon no-text chart-fullscreen__close";
  close.setAttribute("aria-label", label("close"));
  close.innerHTML = iconHTML("xmark");

  const onKey = (event) => {
    if (event.key === "Escape") {
      remove();
    }
  };
  const remove = () => {
    document.removeEventListener("keydown", onKey);
    overlay.remove();
  };

  close.addEventListener("click", remove);
  overlay.addEventListener("click", (event) => {
    // Backdrop click closes; a click on the image does not.
    if (event.target === overlay) {
      remove();
    }
  });
  document.addEventListener("keydown", onKey);

  overlay.append(image, close);
  document.body.append(overlay);
  close.focus();
}

function addButton(chart) {
  if (chart.parentElement?.classList.contains(HOST_CLASS)) {
    return;
  }

  // The button lives beside the chart, not inside it: the plugin owns the div's
  // children and may rebuild them.
  const host = document.createElement("div");
  host.className = HOST_CLASS;
  chart.before(host);
  host.append(chart);

  const button = document.createElement("button");
  button.type = "button";
  button.className = "btn btn-flat btn-icon no-text chart-fullscreen__open";
  button.title = label("open");
  button.setAttribute("aria-label", label("open"));
  button.innerHTML = iconHTML("discourse-expand");
  button.addEventListener("click", () => {
    const canvas = chart.querySelector("canvas");
    if (canvas) {
      openOverlay(canvas, chart.dataset.title || label("open"));
    }
  });
  host.append(button);
}

export default apiInitializer((api) => {
  api.onPageChange(() => {
    schedule("afterRender", () => {
      document.querySelectorAll(CHART_SELECTOR).forEach(addButton);
    });
  });
});
