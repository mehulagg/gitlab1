// Duplicated in app/assets/javascripts/vue_shared/models in EE
// See issue gitlab-ce#61293

export default class ListLabel {
  constructor(obj) {
    this.id = obj.id;
    this.title = obj.title;
    this.type = obj.type;
    this.color = obj.color;
    this.textColor = obj.text_color;
    this.description = obj.description;
    this.priority = obj.priority !== null ? obj.priority : Infinity;
  }
}

window.ListLabel = ListLabel;
