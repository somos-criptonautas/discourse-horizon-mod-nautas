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
// console or server error. With topic-thumbnails active the per-user "AI summaries in
// topic lists" (table_ai) toggle is suppressed, which is what keeps the guard false.
// There is no client-side fix for a missing attribute: the site must satisfy the guard
// (ai_summary_gists_enabled + agent configured + gists actually generated), or
// re-serialize the attribute with its own include-condition from a plugin/initializer.
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
        {{! triple-stache: the value is HTML (AiSummary#summarized_text); double-staching
            would print literal <p>…</p> markup instead of rendering it }}
        <div class="horizon-ai-gist" aria-hidden="true">
          {{{@outletArgs.topic.ai_topic_gist}}}
        </div>
      {{/if}}
    </template>
  );
});
