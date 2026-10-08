import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { apiInitializer } from "discourse/lib/api";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import DButton from "discourse/ui-kit/d-button";
import { themePrefix } from "virtual:theme";

// AI bot conversations: the thumbs down is a reaction, not a flag.
//
// scss/ai-bot.scss only repaints icons, so the thumb that looked like "bad answer" was
// still core's flag button and opened the flag modal. Here, in bot PMs only, the flag
// is swapped for a button that toggles the REACTION below through discourse-reactions'
// own endpoint — no modal, and it is one reaction per user per post, so up and down
// replace each other.
//
// The reaction must be enabled in discourse_reactions_enabled_reactions, or the
// endpoint refuses it (shown as an error popup). "-1" is in the plugin's default
// discourse_reactions_excluded_from_like, so a thumbs down never counts as a like.
const THUMBS_DOWN_REACTION = "-1";

// Fields the toggle response carries that the post menu reads back.
const REACTION_FIELDS = [
  "reactions",
  "current_user_reaction",
  "current_user_used_main_reaction",
  "reaction_users_count",
  "like_count",
];

class AiThumbsDownButton extends Component {
  // The flag it replaces never rendered on your own posts (you cannot flag them);
  // neither does this — rating your own message is meaningless.
  static shouldRender({ post }) {
    return !post.yours;
  }

  @service appEvents;

  @tracked busy = false;

  get active() {
    return this.args.post.current_user_reaction?.id === THUMBS_DOWN_REACTION;
  }

  @action
  async toggle() {
    const post = this.args.post;
    this.busy = true;

    try {
      const result = await ajax(
        `/discourse-reactions/posts/${post.id}/custom-reactions/${THUMBS_DOWN_REACTION}/toggle.json`,
        { type: "PUT" }
      );

      const updates = {};
      REACTION_FIELDS.forEach((field) => {
        if (field in result) {
          updates[field] = result[field];
        }
      });
      post.setProperties(updates);

      this.appEvents.trigger("discourse-reactions:reaction-toggled", {
        post: result,
        reaction: result.current_user_reaction,
      });
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.busy = false;
    }
  }

  <template>
    <DButton
      class="post-action-menu__ai-thumbs-down {{if this.active 'is-active'}}"
      ...attributes
      @action={{this.toggle}}
      @disabled={{this.busy}}
      @icon="ph-dt-thumbs-down"
      @title={{themePrefix "ai_thumbs_down"}}
    />
  </template>
}

export default apiInitializer((api) => {
  // Without discourse-reactions there is no endpoint to call; the flag stays a flag.
  if (!api.container.lookup("service:site-settings").discourse_reactions_enabled) {
    return;
  }

  api.registerValueTransformer(
    "post-menu-buttons",
    ({ value: dag, context: { post, buttonKeys } }) => {
      if (!post.topic?.is_bot_pm) {
        return;
      }

      if (dag.has(buttonKeys.FLAG)) {
        dag.replace(buttonKeys.FLAG, AiThumbsDownButton);
      }
    }
  );
});
