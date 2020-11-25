import $ from 'jquery';
import syntaxHighlight from '~/syntax_highlight';
import renderMath from './render_math';
import renderMermaid from './render_mermaid';
import renderMetrics from './render_metrics';
import highlightCurrentUser from './highlight_current_user';
import initUserPopovers from '../../user_popovers';
import convertTimezone from './convert_timezone'

// Render GitLab flavoured Markdown
//
// Delegates to syntax highlight and render math & mermaid diagrams.
//
$.fn.renderGFM = function renderGFM() {
  syntaxHighlight(this.find('.js-syntax-highlight'));
  renderMath(this.find('.js-render-math'));
  renderMermaid(this.find('.js-render-mermaid'));
  highlightCurrentUser(this.find('.gfm-project_member').get());
  initUserPopovers(this.find('.js-user-link').get());
  convertTimezone(this.find('.js-timezone-link').get())

  const mrPopoverElements = this.find('.gfm-merge_request').get();
  if (mrPopoverElements.length) {
    import(/* webpackChunkName: 'MrPopoverBundle' */ '../../mr_popover')
      .then(({ default: initMRPopovers }) => {
        initMRPopovers(mrPopoverElements);
      })
      .catch(() => {});
  }

  renderMetrics(this.find('.js-render-metrics').get());
  return this;
};

$(() => {
  window.requestIdleCallback(
    () => {
      $('body').renderGFM();
    },
    { timeout: 500 },
  );
});
