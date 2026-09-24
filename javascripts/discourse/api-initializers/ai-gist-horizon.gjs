import Component from "@glimmer/component";
import { service } from "@ember/service";
import bodyClass from "discourse/helpers/body-class";
import { apiInitializer } from "discourse/lib/api";

// Horizon's high-context card deletes core's TopicCell, taking with it both outlets
// discourse-ai renders gists into (topic-list-topic-cell-link-bottom-line__before on
// desktop, topic-list-main-link-bottom on mobile). `topic-list-after-title` is the only
// core outlet the card keeps — and core + topic-thumbnails render it too, so one
// registration covers every layout.
//
// SERVER-SIDE GATE (read this before debugging "why is nothing showing"):
// the attribute only exists when discourse-ai's serializer guard passes —
//   add_to_serializer(:topic_list_item, :ai_topic_gist,
//     include_condition: -> { scope.can_see_gists? })
// If it fails, the attribute is omitted from latest.json entirely (not null), so the
// #if below is simply false and nothing renders, with no console or server error:
//   fetch('/latest.json').then(r=>r.json()).then(d=>
//     console.log(d.topic_list.topics.filter(t=>'ai_topic_gist' in t).length))
//
// can_see_gists? needs ai_summarization_enabled + ai_summary_gists_enabled + an agent
// that ai_summary_gists_agent resolves to, whose allowed_group_ids contain `everyone`
// or one of the viewer's groups. That last clause is the one that bites: backfill
// generates gists without consulting the agent's groups, so the admin UI can show
// healthy gists while every payload omits the attribute. An empty allowed_group_ids
// hides them from everyone.
//
// The gist is plain text, not HTML: discourse-ai prints it with a plain double-stache
// and reserves trustHTML for its excerpt fallback. Keep it escaped — it is LLM output,
// and unescaping it would make it an injection surface. (Note deliberately kept out of
// the template: a {{! }} comment ends at its first closing braces, so mustache syntax
// inside one spills the rest of the comment onto the page.)
//
// aria-hidden: this outlet sits inside Horizon's `role="heading"` title div, whose
// accessible name is computed from its contents — an unhidden gist would append the
// whole summary to every topic heading. The gist is supplementary (the topic it
// summarizes is linked right above it), so hiding it from AT is the lesser cost.

// Categories whose topics never show a gist. Client-side only: the attribute is still
// serialized into every topic list payload and backfill still generates it — discourse-ai
// has no per-category scoping, so this suppresses rendering, not cost.
const HIDDEN_CATEGORIES = new Set(
  (settings.gist_hidden_categories || "")
    .split("|")
    .filter(Boolean)
    .map(Number)
);

class HorizonAiGist extends Component {
  // May not exist if discourse-ai is disabled, hence the optional chaining below. This
  // is the same pattern core itself uses for a possibly-absent service — discourse-ai's
  // own topic-list-gist-toggle injects `topicThumbnails` and optional-chains it.
  @service gists;

  // discourse-ai's toggle writes "table" (compact) or "table-ai" to localStorage and
  // leaves it unset until the user picks one. Unset counts as show, making the toggle
  // an opt-OUT: nobody loses gists they already see just by never touching it.
  get show() {
    if (HIDDEN_CATEGORIES.has(this.args.topic?.category_id)) {
      return false;
    }
    return this.gists?.currentPreference !== "table";
  }

  <template>
    {{#if this.show}}
      <div class="horizon-ai-gist" aria-hidden="true">{{@topic.ai_topic_gist}}</div>
    {{/if}}
  </template>
}

// Three modes, driven by the "Topic Excerpts & AI Gists Button" component:
//   Compact  → gists "table",    prefersExcerpt false → titles only (class below)
//   Excerpts → gists "table",    prefersExcerpt true  → Horizon's excerpt, no gist
//   AI       → gists "table-ai", prefersExcerpt false → gist; excerpt only where no gist
// Horizon always renders its excerpt, so Compact is the one mode that needs CSS help.
// Both services are tracked, so this re-renders when the button flips either one.
class TopicListMode extends Component {
  @service gists;
  @service excerptState;

  get titlesOnly() {
    return (
      this.gists?.currentPreference === "table" &&
      !this.excerptState.prefersExcerpt
    );
  }

  <template>
    {{#if this.titlesOnly}}
      {{bodyClass "horizon-titles-only"}}
    {{/if}}
  </template>
}

// Registered as a bare template on purpose: this form is known to receive @outletArgs.
// The topic is then passed explicitly into the class component above, so the service
// lives in a component whose argument shape we control.
export default apiInitializer((api) => {
  // Gists are on by default here, but the button only labels a state "AI" when the
  // stored preference is literally "table-ai" — unset reads as Compact while gists
  // show. Persist the default so the label matches. Note: this also makes gists the
  // default on non-Horizon lists for that browser, which is the intended semantics.
  const gists = api.container.lookup("service:gists");
  if (gists && !gists.currentPreference) {
    gists.setPreference("table-ai");
  }

  api.renderInOutlet("before-topic-list-body", TopicListMode);

  api.renderInOutlet(
    "topic-list-after-title",
    <template>
      {{#if @outletArgs.topic.ai_topic_gist}}
        <HorizonAiGist @topic={{@outletArgs.topic}} />
      {{/if}}
    </template>
  );
});
