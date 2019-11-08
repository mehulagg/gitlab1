import initGkeDropdowns from '~/create_cluster/gke_cluster';
import initGkeNamespace from '~/projects/gke_cluster_namespace';
import initSourcegraph from '~/sourcegraph';
import PersistentUserCallout from '../../persistent_user_callout';
import Project from './project';
import ShortcutsNavigation from '../../behaviors/shortcuts/shortcuts_navigation';

document.addEventListener('DOMContentLoaded', () => {
  const { page } = document.body.dataset;
  const newClusterViews = [
    'projects:clusters:new',
    'projects:clusters:create_gcp',
    'projects:clusters:create_user',
  ];

  if (newClusterViews.indexOf(page) > -1) {
    const callout = document.querySelector('.gcp-signup-offer');
    PersistentUserCallout.factory(callout);

    initGkeDropdowns();
    initGkeNamespace();
  }

  new Project(); // eslint-disable-line no-new
  new ShortcutsNavigation(); // eslint-disable-line no-new

  initSourcegraph();
});
