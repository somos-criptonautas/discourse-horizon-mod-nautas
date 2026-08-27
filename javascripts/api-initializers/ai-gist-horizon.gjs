import { apiInitializer } from "discourse/lib/api";

// Horizon's high-context card deletes core's TopicCell, taking with it both outlets
// discourse-ai renders gists into (topic-list-topic-cell-link-bottom-line__before on
// desktop, topic-list-main-link-bottom on mobile). `topic-list-after-title` is the only
// core outlet the card keeps — and core + topic-thumbnails render it too, so one
// registration covers every layout.
//
// Reading ai_topic_gist directly also bypasses discourse-ai's per-user "table-ai"
// toggle, which is suppressed outright when topic-thumbnails is active.
//
// No site-setting guard needed: the attribute is only serialized when
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
        <div class="horizon-ai-gist" aria-hidden="true">
          {{@outletArgs.topic.ai_topic_gist}}
        </div>
      {{/if}}
    </template>
  );
});
