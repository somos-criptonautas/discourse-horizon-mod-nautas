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

// Chart.js' defaults are a fixed mid grey for text and a faint black for grid
// lines, which is why the plugin's charts fade on a dark scheme. The theme's own
// tokens follow the active color scheme, light or dark.
function themeColors() {
  const styles = getComputedStyle(document.documentElement);
  return {
    color: styles.getPropertyValue("--primary").trim(),
    gridColor: styles.getPropertyValue("--primary-low-mid").trim(),
  };
}

// Recolour a chart the plugin already drew in the post. New objects on
// chart.options rather than edits in place: pie charts share the plugin's default
// options object, and a mutation there would leak into every later chart.
function applyThemeColors(chart) {
  const { color, gridColor } = themeColors();
  const { options } = chart;
  const plugins = options.plugins ?? {};

  options.color = color;
  for (const scale of Object.values(options.scales ?? {})) {
    scale.ticks = { ...scale.ticks, color };
    scale.title = { ...scale.title, color };
    scale.grid = { ...scale.grid, color: gridColor };
  }
  options.plugins = {
    ...plugins,
    legend: { ...plugins.legend, labels: { ...plugins.legend?.labels, color } },
    title: { ...plugins.title, color },
  };
  chart.update("none");
}

// The plugin's options, enlarged. Spreads rather than a deep clone because the
// plugin's options carry functions (tick formatters) that must survive; data is
// numbers and strings, so JSON copies it without the listeners Chart.js attaches.
function enlargedConfig(config) {
  const { type, data, options } = config;
  const font = { size: FONT_SIZE };
  const plugins = options.plugins ?? {};
  const { color, gridColor } = themeColors();

  const scales = {};
  for (const [key, scale] of Object.entries(options.scales ?? {})) {
    scales[key] = {
      ...scale,
      ticks: { ...scale.ticks, font, color },
      title: { ...scale.title, font, color, padding: 12 },
      grid: { ...scale.grid, color: gridColor },
    };
  }

  return {
    type,
    data: JSON.parse(JSON.stringify(data)),
    options: {
      ...options,
      responsive: true,
      maintainAspectRatio: false,
      color,
      scales,
      elements: { line: { borderWidth: 3 }, point: { radius: 4 } },
      plugins: {
        ...plugins,
        legend: {
          ...plugins.legend,
          labels: { ...plugins.legend?.labels, font, color, padding: 20 },
        },
        title: {
          ...plugins.title,
          color,
          font: { size: FONT_SIZE + 4, weight: "bold" },
          padding: { top: 8, bottom: 28 },
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

  whenCanvas(chart, async (canvas) => {
    const Chart = await loadChartJS();
    const instance = Chart.getChart(canvas);
    if (instance) {
      applyThemeColors(instance);
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
      document.querySelectorAll(CHART_SELECTOR).forEach(addButton);
    });
  });
});
