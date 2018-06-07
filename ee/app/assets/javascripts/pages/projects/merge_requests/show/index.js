import initMrNotes from '~/mr_notes';
import initShow from '~/pages/projects/merge_requests/init_merge_request_show';
import initSidebarBundle from 'ee/sidebar/sidebar_bundle';

document.addEventListener('DOMContentLoaded', () => {
  initShow();
  initSidebarBundle();
  initMrNotes();
});
