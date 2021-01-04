import Vue from 'vue';
import $ from 'jquery';
import App from './components/app.vue';
import { addSubscription, removeSubscription } from '~/jira_connect/api';

const store = {
  state: {
    error: '',
  },
  setErrorMessage(errorMessage) {
    this.state.error = errorMessage;
  },
};

/**
 * Initialize necessary form handlers for the Jira Connect app
 */
const initJiraFormHandlers = () => {
  const reqComplete = () => {
    AP.navigator.reload();
  };

  const reqFailed = (res, fallbackErrorMessage) => {
    const { responseJSON: { error = fallbackErrorMessage } = {} } = res || {};

    store.setErrorMessage(error);
    // eslint-disable-next-line no-alert
    alert(error);
  };

  AP.getLocation((location) => {
    $('.js-jira-connect-sign-in').each(function updateSignInLink() {
      const updatedLink = `${$(this).attr('href')}?return_to=${location}`;
      $(this).attr('href', updatedLink);
    });
  });

  $('#add-subscription-form').on('submit', function onAddSubscriptionForm(e) {
    const addPath = $(this).attr('action');
    const namespace = $('#namespace-input').val();

    e.preventDefault();

    addSubscription(addPath, namespace)
      .then(reqComplete)
      .catch((err) => reqFailed(err.response.data, 'Failed to add namespace. Please try again.'));
  });

  $('.remove-subscription').on('click', function onRemoveSubscriptionClick(e) {
    const removePath = $(this).attr('href');
    e.preventDefault();

    removeSubscription(removePath)
      .then(reqComplete)
      .catch((err) =>
        reqFailed(err.response.data, 'Failed to remove namespace. Please try again.'),
      );
  });
};

function initJiraConnect() {
  const el = document.querySelector('.js-jira-connect-app');

  initJiraFormHandlers();

  return new Vue({
    el,
    data: {
      state: store.state,
    },
    render(createElement) {
      return createElement(App, {});
    },
  });
}

document.addEventListener('DOMContentLoaded', initJiraConnect);
