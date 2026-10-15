import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { apiInitializer } from "discourse/lib/api";
import DButton from "discourse/ui-kit/d-button";
import ChatHeaderIconUnreadIndicator from "discourse/plugins/chat/discourse/components/chat/header/icon/unread-indicator";

// Chat toggle next to the light/dark selector, replacing the sidebar's "chat" panel
// switch button (hidden in main.scss). Opening mirrors core's header chat icon
// (chat/header/icon.gjs), so drawer vs full page follows the user's preference;
// unlike that icon, a second press closes the drawer instead of going full page.
class SidebarChatToggle extends Component {
  @service chat;
  @service chatStateManager;
  @service router;

  get isActive() {
    return this.chatStateManager.isActive;
  }

  @action
  toggleChat() {
    if (this.chatStateManager.isDrawerActive) {
      // same as the drawer's own close button (chat/navbar/close-drawer-button.gjs)
      this.chatStateManager.didCloseDrawer();
      this.chat.activeChannel = null;
    } else if (this.chatStateManager.isFullPageActive) {
      this.router.transitionTo(this.chatStateManager.lastKnownAppURL || "/");
    } else {
      if (this.chatStateManager.isDrawerPreferred) {
        this.chatStateManager.prefersDrawer();
      }
      this.router.transitionTo(
        this.chatStateManager.lastKnownChatURL || "/chat"
      );
    }
  }

  <template>
    <DButton
      class="btn-flat sidebar-footer-actions-button sidebar-chat-toggle
        {{if this.isActive 'sidebar-chat-toggle--active'}}"
      @action={{this.toggleChat}}
      @icon="d-chat"
      @title={{if this.isActive "chat.close" "chat.title_capitalized"}}
      @ariaLabel={{if this.isActive "chat.close" "chat.title_capitalized"}}
    >
      {{! counts and the user's indicator preference are read by the component itself }}
      <ChatHeaderIconUnreadIndicator />
    </DButton>
  </template>
}

export default apiInitializer((api) => {
  // lookup returns undefined when the chat plugin is off
  if (!api.container.lookup("service:chat")?.userCanChat) {
    return;
  }

  api.renderInOutlet("sidebar-footer-actions", SidebarChatToggle);
});
