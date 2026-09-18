import { tracked } from "@glimmer/tracking";
import Service from "@ember/service";

// The "Topic Excerpts & AI Gists Button" component injects `excerptState` but does not
// ship it — it expects the separate topic-list-excerpts component, which targets core's
// list, not Horizon's cards. This provides the only two members the button uses:
// `prefersExcerpt` and `toggleExcerpt()`. If that other component is ever installed,
// remove this file: both would register `service:excerpt-state`.
const KEY = "horizonPrefersExcerpt";

function stored() {
  try {
    return localStorage.getItem(KEY) === "1";
  } catch {
    return false; // storage blocked: fall back to not preferring excerpts
  }
}

export default class ExcerptState extends Service {
  @tracked prefersExcerpt = stored();

  toggleExcerpt() {
    this.prefersExcerpt = !this.prefersExcerpt;
    try {
      localStorage.setItem(KEY, this.prefersExcerpt ? "1" : "0");
    } catch {
      // storage blocked: the choice lasts until reload
    }
  }
}
