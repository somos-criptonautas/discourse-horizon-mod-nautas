import { schedule } from "@ember/runloop";
import { themePrefix } from "virtual:theme";
import { apiInitializer } from "discourse/lib/api";
import { iconHTML } from "discourse/lib/icon-library";
import loadChartJS from "discourse/lib/load-chart-js";
import { i18n } from "discourse-i18n";

// Fullscreen button for discourse-chart, the same affordance Pele gives diagrams.
//
// The plugin draws on a <canvas> at the post's width with Chart.js' 12px labels and
// offers no way to enlarge it. The overlay redraws the chart with Chart.js itself,
// from the live chart's own config (Chart.getChart(canvas) hands it back), sized to
// the viewport and with larger fonts and strokes: vector-sharp at any size. Scaling
// the canvas bitmap instead looked pixelated on 1x screens.
//
// Chart.js comes from core's loader, the same module the plugin uses, so this adds
// no second copy. If no instance is found on the canvas (plugin changed), the bitmap
// is shown as an image rather than nothing.
//
// onPageChange + afterRender rather than decorateCookedElement: the pattern the rest
// of this theme relies on (see checklist-strike.js). addButton() skips charts it has
// already wrapped, so re-running costs a querySelectorAll. The canvas is read at click
// time because the plugin renders it asynchronously, after the cooked HTML is in place.
const CHART_SELECTOR = ".cooked .discourse-chart";
const HOST_CLASS = "chart-fullscreen-host";
const FONT_SIZE = 18;

function label(key) {
  return i18n(themePrefix(`chart_fullscreen.${key}`));
}

// The plugin's options, enlarged. Spreads rather than a deep clone because the
// plugin's options carry functions (tick formatters) that must survive; data is
// numbers and strings, so JSON copies it without the listeners Chart.js attaches.
function enlargedConfig(config) {
  const { type, data, options } = config;
  const font = { size: FONT_SIZE };
  const plugins = options.plugins ?? {};

  const scales = {};
  for (const [key, scale] of Object.entries(options.scales ?? {})) {
    scales[key] = {
      ...scale,
      ticks: { ...scale.ticks, font },
      title: { ...scale.title, font },
    };
  }

  return {
    type,
    data: JSON.parse(JSON.stringify(data)),
    options: {
      ...options,
      responsive: true,
      maintainAspectRatio: false,
      scales,
      elements: { line: { borderWidth: 3 }, point: { radius: 4 } },
      plugins: {
        ...plugins,
        legend: {
          ...plugins.legend,
          labels: { ...plugins.legend?.labels, font },
        },
        title: {
          ...plugins.title,
          font: { size: FONT_SIZE + 4, weight: "bold" },
        },
      },
    },
  };
}

async function openOverlay(canvas, title) {
  const overlay = document.createElement("div");
  overlay.className = "chart-fullscreen";
  overlay.setAttribute("role", "dialog");
  overlay.setAttribute("aria-modal", "true");
  overlay.setAttribute("aria-label", title);

  const close = document.createElement("button");
  close.type = "button";
  close.className = "btn btn-flat btn-icon no-text chart-fullscreen__close";
  close.setAttribute("aria-label", label("close"));
  close.innerHTML = iconHTML("xmark");

  let fullChart;
  const onKey = (event) => {
    if (event.key === "Escape") {
      remove();
    }
  };
  const remove = () => {
    document.removeEventListener("keydown", onKey);
    fullChart?.destroy();
    overlay.remove();
  };

  close.addEventListener("click", remove);
  overlay.addEventListener("click", (event) => {
    // Backdrop click closes; a click on the chart does not.
    if (event.target === overlay) {
      remove();
    }
  });
  document.addEventListener("keydown", onKey);

  const Chart = await loadChartJS();
  const source = Chart.getChart(canvas);

  if (source) {
    // Chart.js sizes a responsive canvas to its parent, which must be a positioned
    // block with its own dimensions: the stage.
    const stage = document.createElement("div");
    stage.className = "chart-fullscreen__stage";
    const target = document.createElement("canvas");
    target.setAttribute("role", "img");
    target.setAttribute("aria-label", title);
    stage.append(target);
    overlay.append(stage, close);
    document.body.append(overlay);
    fullChart = new Chart(target, enlargedConfig(source.config));
  } else {
    const image = document.createElement("img");
    image.className = "chart-fullscreen__image";
    image.src = canvas.toDataURL("image/png");
    image.alt = title;
    overlay.append(image, close);
    document.body.append(overlay);
  }

  close.focus();
}

function addButton(chart) {
  if (chart.parentElement?.classList.contains(HOST_CLASS)) {
    return;
  }

  // The button lives beside the chart, not inside it: the plugin empties the div's
  // innerHTML when it renders.
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
