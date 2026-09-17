import { apiInitializer } from "discourse/lib/api";

// Horizon's high-context card deletes core's TopicCell, taking with it both outlets
// discourse-ai renders gists into (topic-list-topic-cell-link-bottom-line__before on
// desktop, topic-list-main-link-bottom on mobile). `topic-list-after-title` is the only
// core outlet the card keeps — and core + topic-thumbnails render it too, so one
// registration covers every layout.
//
// SERVER-SIDE GATE (read this before debugging "why is nothing showing"):
// reading ai_topic_gist here does NOT bypass discourse-ai's serializer guard —
//   add_to_serializer(:topic_list_item, :ai_topic_gist,
//     include_condition: -> { scope.can_see_gists? })
// If that guard fails server-side, the attribute is left out of latest.json entirely
// (not null — omitted), so the #if below is simply false and nothing renders, with no
// console or server error. Confirm with, on /latest:
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
// There is no client-side fix for a missing attribute — the site must satisfy the
// guard, or a plugin must re-serialize the attribute with its own include-condition.
//
// No site-setting guard needed on our side: the attribute is only serialized when
// Guardian#can_see_gists? passes, so the #if already covers plugin/gists enabled,
// agent resolution, and per-group access.
//
// aria-hidden: this outlet sits inside Horizon's `role="heading"` title div, whose
// accessible name is computed from its contents — an unhidden gist would append the
// whole summary to every topic heading. The gist is supplementary (the topic it
// summarizes is linked right above it), so hiding it from AT is the lesser cost.
export default apiInitializer((api) => {
  api.renderInOutlet(
    "topic-list-after-title",
    <template>
      {{#if @outletArgs.topic.ai_topic_gist}}
        {{! Plain text, not HTML: discourse-ai renders the gist with a plain {{this.gist}}
            and reserves trustHTML for its excerpt fallback. Keep it escaped — this is
            LLM output, and unescaping it would make it an injection surface. }}
        <div class="horizon-ai-gist" aria-hidden="true">
          {{@outletArgs.topic.ai_topic_gist}}
        </div>
      {{/if}}
    </template>
  );
});
