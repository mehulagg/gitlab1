import Vue from 'vue';
import apolloProvider from './graphql/provider';
import OnDemandScansApp from './components/on_demand_scans_app.vue';

export default () => {
  const el = document.querySelector('#js-on-demand-scans-app');
  if (!el) {
    return null;
  }

  const {
    dastSiteValidationDocsPath,
    emptyStateSvgPath,
    projectPath,
    defaultBranch,
    scannerProfilesLibraryPath,
    siteProfilesLibraryPath,
    newSiteProfilePath,
    newScannerProfilePath,
    helpPagePath,
  } = el.dataset;

  return new Vue({
    el,
    apolloProvider,
    provide: {
      scannerProfilesLibraryPath,
      siteProfilesLibraryPath,
      newScannerProfilePath,
      newSiteProfilePath,
      dastSiteValidationDocsPath,
    },
    render(h) {
      return h(OnDemandScansApp, {
        props: {
          helpPagePath,
          emptyStateSvgPath,
          projectPath,
          defaultBranch,
        },
      });
    },
  });
};
