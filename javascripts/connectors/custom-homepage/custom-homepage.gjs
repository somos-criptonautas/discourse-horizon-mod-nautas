import Component from "@glimmer/component";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";

export default class CustomHomepage extends Component {
  @action
  onInsert() {
    // TODO: lounge JS goes here
  }

  <template>
    <div class="custom-homepage" {{didInsert this.onInsert}}></div>
  </template>
}
