import initIssuableSidebar from '~/init_issuable_sidebar';
import Issue from '~/issue';
import ShortcutsIssuable from '~/behaviors/shortcuts/shortcuts_issuable';
import ZenMode from '~/zen_mode';
import '~/notes/index';
import initIssueableApp from '~/issue_show';
import initRelatedMergeRequestsApp from '~/related_merge_requests';

export default function() {
  initIssueableApp();
  initRelatedMergeRequestsApp();
  new Issue(); // eslint-disable-line no-new
  new ShortcutsIssuable(); // eslint-disable-line no-new
  new ZenMode(); // eslint-disable-line no-new
  initIssuableSidebar();
}
