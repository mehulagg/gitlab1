import { shallowMount, createLocalVue } from '@vue/test-utils';
import Vuex from 'vuex';
import Commit from '~/vue_shared/components/commit.vue';
import Project from 'ee/operations/components/dashboard/project.vue';
import ProjectHeader from 'ee/operations/components/dashboard/project_header.vue';
import Alerts from 'ee/operations/components/dashboard/alerts.vue';
import store from 'ee/operations/store';
import { mockOneProject } from '../../mock_data';

const localVue = createLocalVue();
localVue.use(Vuex);

describe('project component', () => {
  const ProjectComponent = localVue.extend(Project);
  let wrapper;

  beforeEach(() => {
    wrapper = shallowMount(ProjectComponent, {
      sync: false,
      store,
      localVue,
      propsData: {
        project: mockOneProject,
      },
    });
  });

  afterEach(() => {
    wrapper.destroy();
  });

  describe('wrapped components', () => {
    describe('project header', () => {
      it('binds project', () => {
        const header = wrapper.find(ProjectHeader);

        expect(header.props('project')).toEqual(mockOneProject);
      });
    });

    describe('alerts', () => {
      let alert;

      beforeEach(() => {
        alert = wrapper.find(Alerts);
      });

      it('binds alert count to count', () => {
        expect(alert.props('count')).toBe(mockOneProject.alert_count);
      });

      it('binds last alert', () => {
        expect(alert.props('lastAlert')).toEqual(mockOneProject.last_alert);
      });
    });

    describe('commit', () => {
      let commit;

      beforeEach(() => {
        commit = wrapper.find(Commit);
      });

      it('binds commitRef', () => {
        expect(commit.props('commitRef')).toBe(wrapper.vm.commitRef);
      });

      it('binds short_id to shortSha', () => {
        expect(commit.props().shortSha).toBe(
          wrapper.props().project.last_deployment.commit.short_id,
        );
      });

      it('binds commitUrl', () => {
        expect(commit.props().commitUrl).toBe(
          wrapper.props().project.last_deployment.commit.commit_url,
        );
      });

      it('binds title', () => {
        expect(commit.props().title).toBe(wrapper.props().project.last_deployment.commit.title);
      });

      it('binds author', () => {
        expect(commit.props().author).toBe(wrapper.vm.author);
      });

      it('binds tag', () => {
        expect(commit.props().tag).toBe(wrapper.props().project.last_deployment.tag);
      });
    });

    describe('last deploy', () => {
      it('renders calendar icon', () => {
        expect(wrapper.contains('.js-dashboard-project-calendar-icon')).toBe(true);
      });

      it('renders time ago of last deploy', () => {
        const timeago = '1 day ago';
        const container = wrapper.element.querySelector('.js-project-container');

        expect(container.innerText.trim()).toBe(timeago);
      });
    });
  });
});
