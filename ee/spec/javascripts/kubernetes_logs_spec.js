import $ from 'jquery';
import KubernetesLogs from 'ee/kubernetes_logs';
import MockAdapter from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import { logMockData, podMockData, mockEnvironmentData } from './kubernetes_mock_data';

describe('Kubernetes Logs', () => {
  const fixtureTemplate = 'static/environments_logs.html';
  let mockDataset;
  let kubernetesLogContainer;
  let kubernetesLog;
  let mock;

  preloadFixtures(fixtureTemplate);

  describe('When data is requested correctly', () => {
    beforeEach(() => {
      loadFixtures(fixtureTemplate);
      spyOnDependency(KubernetesLogs, 'getParameterValues').and.callFake(() => []);
      kubernetesLogContainer = document.querySelector('.js-kubernetes-logs');

      mockDataset = kubernetesLogContainer.dataset;

      mock = new MockAdapter(axios);
      mock.onGet(mockDataset.environmentsPath).reply(200, { environments: mockEnvironmentData });
      mock.onGet(mockDataset.logsPath).reply(200, { logs: logMockData, pods: podMockData });
    });

    afterEach(() => {
      mock.restore();
    });

    it('has the environment name placed on the dropdown', done => {
      kubernetesLog = new KubernetesLogs(kubernetesLogContainer);
      kubernetesLog.getData();

      setTimeout(() => {
        const dropdown = document
          .querySelector('.js-environment-dropdown')
          .querySelector('.dropdown-menu-toggle');

        expect(dropdown.textContent).toContain(mockDataset.environmentName);
        done();
      });
    });

    it('loads all environments as options of the dropdown', done => {
      kubernetesLog = new KubernetesLogs(kubernetesLogContainer);
      kubernetesLog.getData();

      setTimeout(() => {
        const options = document
          .querySelector('.js-environment-dropdown')
          .querySelectorAll('.dropdown-item');

        expect(options.length).toEqual(mockEnvironmentData.length);
        options.forEach((item, i) => {
          expect(item.textContent.trim()).toBe(mockEnvironmentData[i].name);
        });
        done();
      });
    });

    it('has the pod name placed on the dropdown', done => {
      kubernetesLog = new KubernetesLogs(kubernetesLogContainer);
      kubernetesLog.getData();

      setTimeout(() => {
        const podDropdown = document
          .querySelector('.js-pod-dropdown')
          .querySelector('.dropdown-menu-toggle');

        expect(podDropdown.textContent).toContain(podMockData[0]);
        done();
      });
    });

    it('queries the pod log data and sets the dom elements', done => {
      const scrollSpy = spyOnDependency(KubernetesLogs, 'scrollDown').and.callThrough();
      const toggleDisableSpy = spyOnDependency(KubernetesLogs, 'toggleDisableButton').and.stub();
      kubernetesLog = new KubernetesLogs(kubernetesLogContainer);

      expect(kubernetesLog.isLogComplete).toEqual(false);

      kubernetesLog.getData();
      setTimeout(() => {
        expect(kubernetesLog.isLogComplete).toEqual(true);

        expect(document.querySelector('.js-build-output').textContent).toContain(
          logMockData[0].trim(),
        );

        expect(scrollSpy).toHaveBeenCalled();
        expect(toggleDisableSpy).toHaveBeenCalled();
        done();
      });
    });

    it('asks for the pod logs from another pod', done => {
      const changePodLogSpy = spyOn(KubernetesLogs.prototype, 'getData').and.callThrough();
      kubernetesLog = new KubernetesLogs(kubernetesLogContainer);

      kubernetesLog.getData();
      setTimeout(() => {
        const podDropdown = document.querySelectorAll('.js-pod-dropdown .dropdown-menu button');
        const anotherPod = podDropdown[podDropdown.length - 1];

        anotherPod.click();

        expect(changePodLogSpy.calls.count()).toEqual(2);
        done();
      }, 0);
    });

    it('clears the pod dropdown contents when pod logs are requested', done => {
      const emptySpy = spyOn($.prototype, 'empty').and.callThrough();
      kubernetesLog = new KubernetesLogs(kubernetesLogContainer);
      kubernetesLog.getData();

      setTimeout(() => {
        // 3 elems should be emptied:
        //   1. the environment dropdown items
        //   2. the pods dropdown items
        //   3. the job log contents
        expect(emptySpy.calls.count()).toEqual(3);
        done();
      });
    });
  });

  describe('XSS Protection', () => {
    const hackyPodName = '">&lt;img src=x onerror=alert(document.domain)&gt; production';
    beforeEach(() => {
      loadFixtures(fixtureTemplate);
      spyOnDependency(KubernetesLogs, 'getParameterValues').and.callFake(() => [hackyPodName]);
      kubernetesLogContainer = document.querySelector('.js-kubernetes-logs');

      mock = new MockAdapter(axios);
      mock.onGet(mockDataset.logsPath).reply(200, { logs: logMockData, pods: [hackyPodName] });
    });

    afterEach(() => {
      mock.restore();
    });

    it('escapes the pod name', () => {
      kubernetesLog = new KubernetesLogs(kubernetesLogContainer);

      expect(kubernetesLog.podName).toContain(
        '&quot;&gt;&amp;lt;img src=x onerror=alert(document.domain)&amp;gt; production',
      );
    });
  });

  describe('When data is not yet loaded into cache', () => {
    beforeEach(() => {
      loadFixtures(fixtureTemplate);
      spyOnDependency(KubernetesLogs, 'getParameterValues').and.callFake(() => [podMockData[1]]);
      kubernetesLogContainer = document.querySelector('.js-kubernetes-logs');

      const origSetTimeout = window.setTimeout;
      spyOn(window, 'setTimeout').and.callFake(cb => origSetTimeout(cb, 0));

      mockDataset = kubernetesLogContainer.dataset;

      mock = new MockAdapter(axios);
      mock.onGet(mockDataset.environmentsPath).reply(200, { environments: mockEnvironmentData });
      // Simulate reactive cache, 2 tries needed
      mock.onGet(`${mockDataset.logsPath}`, { pod_name: podMockData[1] }).replyOnce(202);
      mock
        .onGet(`${mockDataset.logsPath}`, { pod_name: podMockData[1] })
        .reply(200, { logs: logMockData, pods: podMockData });
    });

    it('queries the pod log data polling for reactive cache', done => {
      kubernetesLog = new KubernetesLogs(kubernetesLogContainer);

      expect(kubernetesLog.isLogComplete).toEqual(false);

      kubernetesLog
        .getData()
        .then(() => {
          const calls = mock.history.get.filter(r => r.url === mockDataset.logsPath);

          // expect 2 tries
          expect(calls.length).toEqual(2);
          expect(calls[0].params).toEqual({ pod_name: podMockData[1] });
          expect(calls[1].params).toEqual({ pod_name: podMockData[1] });

          expect(document.querySelector('.js-build-output').textContent).toContain(
            logMockData[0].trim(),
          );

          done();
        })
        .catch(done.fail);
    });

    afterEach(() => {
      mock.restore();
    });
  });

  describe('When data is requested with a pod name', () => {
    beforeEach(() => {
      loadFixtures(fixtureTemplate);
      spyOnDependency(KubernetesLogs, 'getParameterValues').and.callFake(() => [podMockData[2]]);
      kubernetesLogContainer = document.querySelector('.js-kubernetes-logs');

      mock = new MockAdapter(axios);
    });

    it('logs are loaded with the correct pod_name parameter', () => {
      kubernetesLog = new KubernetesLogs(kubernetesLogContainer);
      kubernetesLog.getData();

      setTimeout(() => {
        const logsCall = mock.history.get.filter(call => call.url === mockDataset.logsPath);

        expect(logsCall.length).toBe(1);
        expect(logsCall[0].params.pod_name).toEqual(podMockData[2]);
      });
    });

    afterEach(() => {
      mock.restore();
    });
  });
});
