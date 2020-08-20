import $ from 'jquery';
import { __ } from '~/locale';
import axios from './lib/utils/axios_utils';
import { deprecatedCreateFlash as flash } from './flash';

const tooltipTitles = {
  group: __('Unsubscribe at group level'),
  project: __('Unsubscribe at project level'),
};

export default class GroupLabelSubscription {
  constructor(container) {
    const $container = $(container);
    this.$dropdown = $container.find('.dropdown');
    this.$subscribeButtons = $container.find('.js-subscribe-button');
    this.$unsubscribeButtons = $container.find('.js-unsubscribe-button');

    this.$subscribeButtons.on('click', this.subscribe.bind(this));
    this.$unsubscribeButtons.on('click', this.unsubscribe.bind(this));
  }

  unsubscribe(event) {
    event.preventDefault();

    const url = this.$unsubscribeButtons.attr('data-url');
    axios
      .post(url)
      .then(() => {
        this.toggleSubscriptionButtons();
        this.$unsubscribeButtons.removeAttr('data-url');
      })
      .catch(() => flash(__('There was an error when unsubscribing from this label.')));
  }

  subscribe(event) {
    event.preventDefault();

    const $btn = $(event.currentTarget);
    const url = $btn.attr('data-url');

    this.$unsubscribeButtons.attr('data-url', url);

    axios
      .post(url)
      .then(() => GroupLabelSubscription.setNewTooltip($btn))
      .then(() => this.toggleSubscriptionButtons())
      .catch(() => flash(__('There was an error when subscribing to this label.')));
  }

  toggleSubscriptionButtons() {
    this.$dropdown.toggleClass('hidden');
    this.$subscribeButtons.toggleClass('hidden');
    this.$unsubscribeButtons.toggleClass('hidden');
  }

  static setNewTooltip($button) {
    if (!$button.hasClass('js-subscribe-button')) return;

    const type = $button.hasClass('js-group-level') ? 'group' : 'project';
    const newTitle = tooltipTitles[type];

    $('.js-unsubscribe-button', $button.closest('.label-actions-list'))
      .tooltip('hide')
      .attr('title', newTitle)
      .tooltip('_fixTitle');
  }
}
