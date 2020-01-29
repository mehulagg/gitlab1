import initAdmin from './admin';
import initAdminStatisticsPanel from '../../admin/statistics_panel/index';
import initVueAlerts from '../../vue_alerts';

initVueAlerts();


document.addEventListener('DOMContentLoaded', () => {
  const statisticsPanelContainer = document.getElementById('js-admin-statistics-container');
  initAdmin();
  initAdminStatisticsPanel(statisticsPanelContainer);
});
