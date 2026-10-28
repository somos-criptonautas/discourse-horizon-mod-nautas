import { schedule } from "@ember/runloop";
import { themePrefix } from "virtual:theme";
import { apiInitializer } from "discourse/lib/api";
import { iconHTML } from "discourse/lib/icon-library";
import loadChartJS from "discourse/lib/load-chart-js";
import { i18n } from "discourse-i18n";

// discourse-chart, restyled and with a fullscreen button, the affordance Pele gives
// diagrams.
//
// The plugin draws on a <canvas> with Chart.js' defaults: 12px labels, a fixed mid
// grey for text and a faint black for grid lines, which fade on a dark scheme, and no
// way to enlarge the chart. This initializer takes the live instance back from the
// canvas (Chart.getChart) and restyles it with the theme's colour tokens and the
// `chart_font_size` setting; the fullscreen overlay redraws the same config, sized to
// the viewport and a few points larger. Both are vector redraws, never a scaled bitmap
// (which looked pixelated on 1x screens).
//
// Chart.js comes from core's loader, the same module the plugin uses, so this adds
// no second copy. If no instance is found on the canvas (plugin changed), the overlay
// falls back to the bitmap as an image rather than nothing.
//
// onPageChange + afterRender rather than decorateCookedElement: the pattern the rest
// of this theme relies on (see checklist-strike.js). enhance() skips charts it has
// already wrapped, so re-running costs a querySelectorAll. The canvas is awaited
// because the plugin renders it asynchronously, after the cooked HTML is in place.
const CHART_SELECTOR = ".cooked .discourse-chart";
const HOST_CLASS = "chart-fullscreen-host";
const FULLSCREEN_EXTRA = 4;

function label(key) {
  return i18n(themePrefix(`chart_fullscreen.${key}`));
}

function fontSize() {
  return Number(settings.chart_font_size) || 14;
}

// The theme's own tokens follow the active colour scheme, light or dark.
function themeColors() {
  const styles = getComputedStyle(document.documentElement);
  return {
    color: styles.getPropertyValue("--primary").trim(),
    gridColor: styles.getPropertyValue("--primary-low-mid").trim(),
  };
}

// New options from the plugin's: theme colours, one font size everywhere, and no
// axis title when the post gave none (the plugin sets display: true with a null
// text, which Chart.js prints as "null"). Spreads rather than a deep clone: the
// plugin's options carry functions (tick formatters) that must survive, and pie
// charts share the plugin's default options object, which must not be mutated.
function restyle(options, size) {
  const { color, gridColor } = themeColors();
  const font = { size };
  const plugins = options.plugins ?? {};

  const scales = {};
  for (const [key, scale] of Object.entries(options.scales ?? {})) {
    const title = { ...scale.title, font, color };
    if (title.text === null || title.text === undefined) {
      title.display = false;
    }
    scales[key] = {
      ...scale,
      title,
      ticks: { ...scale.ticks, font, color },
      // No grid: the plugin's charts never showed one (Chart.js' default is a 10%
      // black, invisible on dark). Only the axis line keeps the token colour.
      grid: { ...scale.grid, display: false },
      border: { ...scale.border, color: gridColor },
    };
  }

  return {
    ...options,
    color,
    font,
    scales,
    plugins: {
      ...plugins,
      legend: {
        ...plugins.legend,
        labels: { ...plugins.legend?.labels, font, color, padding: size },
      },
      title: {
        ...plugins.title,
        color,
        font: { size: size + 4, weight: "bold" },
        padding: { top: 8, bottom: size + 10 },
      },
    },
  };
}

function enlargedConfig(config) {
  const { type, data, options } = config;
  const size = fontSize() + FULLSCREEN_EXTRA;

  return {
    type,
    // Numbers and strings only, so JSON copies the data without the listeners
    // Chart.js attaches to the live arrays.
    data: JSON.parse(JSON.stringify(data)),
    options: {
      ...restyle(options, size),
      responsive: true,
      maintainAspectRatio: false,
      elements: { line: { borderWidth: 3 }, point: { radius: 4 } },
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

// The plugin appends its canvas asynchronously, after loading Chart.js; the instance
// exists by the time the canvas is in the DOM (it is built first, appended after).
function whenCanvas(chart, callback) {
  const canvas = chart.querySelector("canvas");
  if (canvas) {
    return callback(canvas);
  }

  const observer = new MutationObserver(() => {
    const found = chart.querySelector("canvas");
    if (found) {
      observer.disconnect();
      callback(found);
    }
  });
  observer.observe(chart, { childList: true });
}

function enhance(chart) {
  if (chart.parentElement?.classList.contains(HOST_CLASS)) {
    return;
  }

  // The button lives beside the chart, not inside it: the plugin empties the div's
  // innerHTML when it renders.
  const host = document.createElement("div");
  host.className = HOST_CLASS;
  chart.before(host);
  host.append(chart);

  whenCanvas(chart, async (canvas) => {
    const Chart = await loadChartJS();
    const instance = Chart.getChart(canvas);
    if (instance) {
      // config.options is the raw object the plugin passed in; instance.options
      // is a resolver proxy over it and the defaults, which does not survive a
      // spread. update() rebuilds the resolver from config.options.
      instance.config.options = restyle(instance.config.options, fontSize());
      instance.update("none");
    }
  });

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
      document.querySelectorAll(CHART_SELECTOR).forEach(enhance);
    });
  });
});
