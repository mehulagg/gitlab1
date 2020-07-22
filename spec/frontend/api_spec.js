import MockAdapter from 'axios-mock-adapter';
import axios from '~/lib/utils/axios_utils';
import Api from '~/api';

describe('Api', () => {
  const dummyApiVersion = 'v3000';
  const dummyUrlRoot = '/gitlab';
  const dummyGon = {
    api_version: dummyApiVersion,
    relative_url_root: dummyUrlRoot,
  };
  let originalGon;
  let mock;

  beforeEach(() => {
    mock = new MockAdapter(axios);
    originalGon = window.gon;
    window.gon = { ...dummyGon };
  });

  afterEach(() => {
    mock.restore();
    window.gon = originalGon;
  });

  describe('buildUrl', () => {
    it('adds URL root and fills in API version', () => {
      const input = '/api/:version/foo/bar';
      const expectedOutput = `${dummyUrlRoot}/api/${dummyApiVersion}/foo/bar`;

      const builtUrl = Api.buildUrl(input);

      expect(builtUrl).toEqual(expectedOutput);
    });

    [null, '', '/'].forEach(root => {
      it(`works when relative_url_root is ${root}`, () => {
        window.gon.relative_url_root = root;
        const input = '/api/:version/foo/bar';
        const expectedOutput = `/api/${dummyApiVersion}/foo/bar`;

        const builtUrl = Api.buildUrl(input);

        expect(builtUrl).toEqual(expectedOutput);
      });
    });
  });

  describe('packages', () => {
    const projectId = 'project_a';
    const packageId = 'package_b';
    const apiResponse = [{ id: 1, name: 'foo' }];

    describe('groupPackages', () => {
      const groupId = 'group_a';

      it('fetch all group packages', () => {
        const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/groups/${groupId}/packages`;
        jest.spyOn(axios, 'get');
        mock.onGet(expectedUrl).replyOnce(200, apiResponse);

        return Api.groupPackages(groupId).then(({ data }) => {
          expect(data).toEqual(apiResponse);
          expect(axios.get).toHaveBeenCalledWith(expectedUrl, {});
        });
      });
    });

    describe('projectPackages', () => {
      it('fetch all project packages', () => {
        const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/${projectId}/packages`;
        jest.spyOn(axios, 'get');
        mock.onGet(expectedUrl).replyOnce(200, apiResponse);

        return Api.projectPackages(projectId).then(({ data }) => {
          expect(data).toEqual(apiResponse);
          expect(axios.get).toHaveBeenCalledWith(expectedUrl, {});
        });
      });
    });

    describe('buildProjectPackageUrl', () => {
      it('returns the right url', () => {
        const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/${projectId}/packages/${packageId}`;
        const url = Api.buildProjectPackageUrl(projectId, packageId);
        expect(url).toEqual(expectedUrl);
      });
    });

    describe('projectPackage', () => {
      it('fetch package details', () => {
        const expectedUrl = `foo`;
        jest.spyOn(Api, 'buildProjectPackageUrl').mockReturnValue(expectedUrl);
        jest.spyOn(axios, 'get');
        mock.onGet(expectedUrl).replyOnce(200, apiResponse);

        return Api.projectPackage(projectId, packageId).then(({ data }) => {
          expect(data).toEqual(apiResponse);
          expect(axios.get).toHaveBeenCalledWith(expectedUrl);
        });
      });
    });

    describe('deleteProjectPackage', () => {
      it('delete a package', () => {
        const expectedUrl = `foo`;

        jest.spyOn(Api, 'buildProjectPackageUrl').mockReturnValue(expectedUrl);
        jest.spyOn(axios, 'delete');
        mock.onDelete(expectedUrl).replyOnce(200, true);

        return Api.deleteProjectPackage(projectId, packageId).then(({ data }) => {
          expect(data).toEqual(true);
          expect(axios.delete).toHaveBeenCalledWith(expectedUrl);
        });
      });
    });
  });

  describe('group', () => {
    it('fetches a group', done => {
      const groupId = '123456';
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/groups/${groupId}`;
      mock.onGet(expectedUrl).reply(200, {
        name: 'test',
      });

      Api.group(groupId, response => {
        expect(response.name).toBe('test');
        done();
      });
    });
  });

  describe('groupMembers', () => {
    it('fetches group members', done => {
      const groupId = '54321';
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/groups/${groupId}/members`;
      const expectedData = [{ id: 7 }];
      mock.onGet(expectedUrl).reply(200, expectedData);

      Api.groupMembers(groupId)
        .then(({ data }) => {
          expect(data).toEqual(expectedData);
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('groups', () => {
    it('fetches groups', done => {
      const query = 'dummy query';
      const options = { unused: 'option' };
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/groups.json`;
      mock.onGet(expectedUrl).reply(200, [
        {
          name: 'test',
        },
      ]);

      Api.groups(query, options, response => {
        expect(response.length).toBe(1);
        expect(response[0].name).toBe('test');
        done();
      });
    });
  });

  describe('namespaces', () => {
    it('fetches namespaces', done => {
      const query = 'dummy query';
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/namespaces.json`;
      mock.onGet(expectedUrl).reply(200, [
        {
          name: 'test',
        },
      ]);

      Api.namespaces(query, response => {
        expect(response.length).toBe(1);
        expect(response[0].name).toBe('test');
        done();
      });
    });
  });

  describe('projects', () => {
    it('fetches projects with membership when logged in', done => {
      const query = 'dummy query';
      const options = { unused: 'option' };
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects.json`;
      window.gon.current_user_id = 1;
      mock.onGet(expectedUrl).reply(200, [
        {
          name: 'test',
        },
      ]);

      Api.projects(query, options, response => {
        expect(response.length).toBe(1);
        expect(response[0].name).toBe('test');
        done();
      });
    });

    it('fetches projects without membership when not logged in', done => {
      const query = 'dummy query';
      const options = { unused: 'option' };
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects.json`;
      mock.onGet(expectedUrl).reply(200, [
        {
          name: 'test',
        },
      ]);

      Api.projects(query, options, response => {
        expect(response.length).toBe(1);
        expect(response[0].name).toBe('test');
        done();
      });
    });
  });

  describe('updateProject', () => {
    it('update a project with the given payload', done => {
      const projectPath = 'foo';
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/${projectPath}`;
      mock.onPut(expectedUrl).reply(200, { foo: 'bar' });

      Api.updateProject(projectPath, { foo: 'bar' })
        .then(({ data }) => {
          expect(data.foo).toBe('bar');
          done();
        })
        .catch(done.fail);
    });
  });

  describe('projectUsers', () => {
    it('fetches all users of a particular project', done => {
      const query = 'dummy query';
      const options = { unused: 'option' };
      const projectPath = 'gitlab-org%2Fgitlab-ce';
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/${projectPath}/users`;
      mock.onGet(expectedUrl).reply(200, [
        {
          name: 'test',
        },
      ]);

      Api.projectUsers('gitlab-org/gitlab-ce', query, options)
        .then(response => {
          expect(response.length).toBe(1);
          expect(response[0].name).toBe('test');
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('projectMergeRequests', () => {
    const projectPath = 'abc';
    const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/${projectPath}/merge_requests`;

    it('fetches all merge requests for a project', done => {
      const mockData = [{ source_branch: 'foo' }, { source_branch: 'bar' }];
      mock.onGet(expectedUrl).reply(200, mockData);
      Api.projectMergeRequests(projectPath)
        .then(({ data }) => {
          expect(data.length).toEqual(2);
          expect(data[0].source_branch).toBe('foo');
          expect(data[1].source_branch).toBe('bar');
        })
        .then(done)
        .catch(done.fail);
    });

    it('fetches merge requests filtered with passed params', done => {
      const params = {
        source_branch: 'bar',
      };
      const mockData = [{ source_branch: 'bar' }];
      mock.onGet(expectedUrl, { params }).reply(200, mockData);

      Api.projectMergeRequests(projectPath, params)
        .then(({ data }) => {
          expect(data.length).toEqual(1);
          expect(data[0].source_branch).toBe('bar');
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('projectMergeRequest', () => {
    it('fetches a merge request', done => {
      const projectPath = 'abc';
      const mergeRequestId = '123456';
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/${projectPath}/merge_requests/${mergeRequestId}`;
      mock.onGet(expectedUrl).reply(200, {
        title: 'test',
      });

      Api.projectMergeRequest(projectPath, mergeRequestId)
        .then(({ data }) => {
          expect(data.title).toBe('test');
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('projectMergeRequestChanges', () => {
    it('fetches the changes of a merge request', done => {
      const projectPath = 'abc';
      const mergeRequestId = '123456';
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/${projectPath}/merge_requests/${mergeRequestId}/changes`;
      mock.onGet(expectedUrl).reply(200, {
        title: 'test',
      });

      Api.projectMergeRequestChanges(projectPath, mergeRequestId)
        .then(({ data }) => {
          expect(data.title).toBe('test');
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('projectMergeRequestVersions', () => {
    it('fetches the versions of a merge request', done => {
      const projectPath = 'abc';
      const mergeRequestId = '123456';
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/${projectPath}/merge_requests/${mergeRequestId}/versions`;
      mock.onGet(expectedUrl).reply(200, [
        {
          id: 123,
        },
      ]);

      Api.projectMergeRequestVersions(projectPath, mergeRequestId)
        .then(({ data }) => {
          expect(data.length).toBe(1);
          expect(data[0].id).toBe(123);
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('projectRunners', () => {
    it('fetches the runners of a project', done => {
      const projectPath = 7;
      const params = { scope: 'active' };
      const mockData = [{ id: 4 }];
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/${projectPath}/runners`;
      mock.onGet(expectedUrl, { params }).reply(200, mockData);

      Api.projectRunners(projectPath, { params })
        .then(({ data }) => {
          expect(data).toEqual(mockData);
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('newLabel', () => {
    it('creates a new label', done => {
      const namespace = 'some namespace';
      const project = 'some project';
      const labelData = { some: 'data' };
      const expectedUrl = `${dummyUrlRoot}/${namespace}/${project}/-/labels`;
      const expectedData = {
        label: labelData,
      };
      mock.onPost(expectedUrl).reply(config => {
        expect(config.data).toBe(JSON.stringify(expectedData));

        return [
          200,
          {
            name: 'test',
          },
        ];
      });

      Api.newLabel(namespace, project, labelData, response => {
        expect(response.name).toBe('test');
        done();
      });
    });

    it('creates a group label', done => {
      const namespace = 'group/subgroup';
      const labelData = { some: 'data' };
      const expectedUrl = Api.buildUrl(Api.groupLabelsPath).replace(':namespace_path', namespace);
      const expectedData = {
        label: labelData,
      };
      mock.onPost(expectedUrl).reply(config => {
        expect(config.data).toBe(JSON.stringify(expectedData));

        return [
          200,
          {
            name: 'test',
          },
        ];
      });

      Api.newLabel(namespace, undefined, labelData, response => {
        expect(response.name).toBe('test');
        done();
      });
    });
  });

  describe('groupProjects', () => {
    it('fetches group projects', done => {
      const groupId = '123456';
      const query = 'dummy query';
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/groups/${groupId}/projects.json`;
      mock.onGet(expectedUrl).reply(200, [
        {
          name: 'test',
        },
      ]);

      Api.groupProjects(groupId, query, {}, response => {
        expect(response.length).toBe(1);
        expect(response[0].name).toBe('test');
        done();
      });
    });
  });

  describe('commit', () => {
    const projectId = 'user/project';
    const sha = 'abcd0123';
    const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/${encodeURIComponent(
      projectId,
    )}/repository/commits/${sha}`;

    it('fetches a single commit', () => {
      mock.onGet(expectedUrl).reply(200, { id: sha });

      return Api.commit(projectId, sha).then(({ data: commit }) => {
        expect(commit.id).toBe(sha);
      });
    });

    it('fetches a single commit without stats', () => {
      mock.onGet(expectedUrl, { params: { stats: false } }).reply(200, { id: sha });

      return Api.commit(projectId, sha, { stats: false }).then(({ data: commit }) => {
        expect(commit.id).toBe(sha);
      });
    });
  });

  describe('issueTemplate', () => {
    it('fetches an issue template', done => {
      const namespace = 'some namespace';
      const project = 'some project';
      const templateKey = ' template #%?.key ';
      const templateType = 'template type';
      const expectedUrl = `${dummyUrlRoot}/${namespace}/${project}/templates/${templateType}/${encodeURIComponent(
        templateKey,
      )}`;
      mock.onGet(expectedUrl).reply(200, 'test');

      Api.issueTemplate(namespace, project, templateKey, templateType, (error, response) => {
        expect(response).toBe('test');
        done();
      });
    });
  });

  describe('projectTemplates', () => {
    it('fetches a list of templates', done => {
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/gitlab-org%2Fgitlab-ce/templates/licenses`;

      mock.onGet(expectedUrl).reply(200, 'test');

      Api.projectTemplates('gitlab-org/gitlab-ce', 'licenses', {}, response => {
        expect(response).toBe('test');
        done();
      });
    });
  });

  describe('projectTemplate', () => {
    it('fetches a single template', done => {
      const data = { unused: 'option' };
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/gitlab-org%2Fgitlab-ce/templates/licenses/test%20license`;

      mock.onGet(expectedUrl).reply(200, 'test');

      Api.projectTemplate('gitlab-org/gitlab-ce', 'licenses', 'test license', data, response => {
        expect(response).toBe('test');
        done();
      });
    });
  });

  describe('users', () => {
    it('fetches users', done => {
      const query = 'dummy query';
      const options = { unused: 'option' };
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/users.json`;
      mock.onGet(expectedUrl).reply(200, [
        {
          name: 'test',
        },
      ]);

      Api.users(query, options)
        .then(({ data }) => {
          expect(data.length).toBe(1);
          expect(data[0].name).toBe('test');
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('user', () => {
    it('fetches single user', done => {
      const userId = '123456';
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/users/${userId}`;
      mock.onGet(expectedUrl).reply(200, {
        name: 'testuser',
      });

      Api.user(userId)
        .then(({ data }) => {
          expect(data.name).toBe('testuser');
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('user counts', () => {
    it('fetches single user counts', done => {
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/user_counts`;
      mock.onGet(expectedUrl).reply(200, {
        merge_requests: 4,
      });

      Api.userCounts()
        .then(({ data }) => {
          expect(data.merge_requests).toBe(4);
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('user status', () => {
    it('fetches single user status', done => {
      const userId = '123456';
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/users/${userId}/status`;
      mock.onGet(expectedUrl).reply(200, {
        message: 'testmessage',
      });

      Api.userStatus(userId)
        .then(({ data }) => {
          expect(data.message).toBe('testmessage');
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('user projects', () => {
    it('fetches all projects that belong to a particular user', done => {
      const query = 'dummy query';
      const options = { unused: 'option' };
      const userId = '123456';
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/users/${userId}/projects`;
      mock.onGet(expectedUrl).reply(200, [
        {
          name: 'test',
        },
      ]);

      Api.userProjects(userId, query, options, response => {
        expect(response.length).toBe(1);
        expect(response[0].name).toBe('test');
        done();
      });
    });
  });

  describe('commitPipelines', () => {
    it('fetches pipelines for a given commit', done => {
      const projectId = 'example/foobar';
      const commitSha = 'abc123def';
      const expectedUrl = `${dummyUrlRoot}/${projectId}/commit/${commitSha}/pipelines`;
      mock.onGet(expectedUrl).reply(200, [
        {
          name: 'test',
        },
      ]);

      Api.commitPipelines(projectId, commitSha)
        .then(({ data }) => {
          expect(data.length).toBe(1);
          expect(data[0].name).toBe('test');
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('createBranch', () => {
    it('creates new branch', done => {
      const ref = 'master';
      const branch = 'new-branch-name';
      const dummyProjectPath = 'gitlab-org/gitlab-ce';
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/${encodeURIComponent(
        dummyProjectPath,
      )}/repository/branches`;

      jest.spyOn(axios, 'post');

      mock.onPost(expectedUrl).replyOnce(200, {
        name: branch,
      });

      Api.createBranch(dummyProjectPath, { ref, branch })
        .then(({ data }) => {
          expect(data.name).toBe(branch);
          expect(axios.post).toHaveBeenCalledWith(expectedUrl, { ref, branch });
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('projectForks', () => {
    it('gets forked projects', done => {
      const dummyProjectPath = 'gitlab-org/gitlab-ce';
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/${encodeURIComponent(
        dummyProjectPath,
      )}/forks`;

      jest.spyOn(axios, 'get');

      mock.onGet(expectedUrl).replyOnce(200, ['fork']);

      Api.projectForks(dummyProjectPath, { visibility: 'private' })
        .then(({ data }) => {
          expect(data).toEqual(['fork']);
          expect(axios.get).toHaveBeenCalledWith(expectedUrl, {
            params: { visibility: 'private' },
          });
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('release', () => {
    const dummyProjectPath = 'gitlab-org/gitlab';
    const dummyTagName = 'v1.3';
    const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/${encodeURIComponent(
      dummyProjectPath,
    )}/releases/${encodeURIComponent(dummyTagName)}`;

    describe('when the release is successfully returned', () => {
      it('resolves the Promise', () => {
        mock.onGet(expectedUrl).replyOnce(200);

        return Api.release(dummyProjectPath, dummyTagName).then(() => {
          expect(mock.history.get).toHaveLength(1);
        });
      });
    });

    describe('when an error occurs while fetching the release', () => {
      it('rejects the Promise', () => {
        mock.onGet(expectedUrl).replyOnce(500);

        return Api.release(dummyProjectPath, dummyTagName).catch(() => {
          expect(mock.history.get).toHaveLength(1);
        });
      });
    });
  });

  describe('createRelease', () => {
    const dummyProjectPath = 'gitlab-org/gitlab';
    const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/${encodeURIComponent(
      dummyProjectPath,
    )}/releases`;

    const release = {
      name: 'Version 1.0',
    };

    describe('when the release is successfully created', () => {
      it('resolves the Promise', () => {
        mock.onPost(expectedUrl, release).replyOnce(201);

        return Api.createRelease(dummyProjectPath, release).then(() => {
          expect(mock.history.post).toHaveLength(1);
        });
      });
    });

    describe('when an error occurs while creating the release', () => {
      it('rejects the Promise', () => {
        mock.onPost(expectedUrl, release).replyOnce(500);

        return Api.createRelease(dummyProjectPath, release).catch(() => {
          expect(mock.history.post).toHaveLength(1);
        });
      });
    });
  });

  describe('updateRelease', () => {
    const dummyProjectPath = 'gitlab-org/gitlab';
    const dummyTagName = 'v1.3';
    const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/${encodeURIComponent(
      dummyProjectPath,
    )}/releases/${encodeURIComponent(dummyTagName)}`;

    const release = {
      name: 'Version 1.0',
    };

    describe('when the release is successfully created', () => {
      it('resolves the Promise', () => {
        mock.onPut(expectedUrl, release).replyOnce(200);

        return Api.updateRelease(dummyProjectPath, dummyTagName, release).then(() => {
          expect(mock.history.put).toHaveLength(1);
        });
      });
    });

    describe('when an error occurs while creating the release', () => {
      it('rejects the Promise', () => {
        mock.onPut(expectedUrl, release).replyOnce(500);

        return Api.updateRelease(dummyProjectPath, dummyTagName, release).catch(() => {
          expect(mock.history.put).toHaveLength(1);
        });
      });
    });
  });

  describe('createReleaseLink', () => {
    const dummyProjectPath = 'gitlab-org/gitlab';
    const dummyReleaseTag = 'v1.3';
    const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/${encodeURIComponent(
      dummyProjectPath,
    )}/releases/${dummyReleaseTag}/assets/links`;
    const expectedLink = {
      url: 'https://example.com',
      name: 'An example link',
    };

    describe('when the Release is successfully created', () => {
      it('resolves the Promise', () => {
        mock.onPost(expectedUrl, expectedLink).replyOnce(201);

        return Api.createReleaseLink(dummyProjectPath, dummyReleaseTag, expectedLink).then(() => {
          expect(mock.history.post).toHaveLength(1);
        });
      });
    });

    describe('when an error occurs while creating the Release', () => {
      it('rejects the Promise', () => {
        mock.onPost(expectedUrl, expectedLink).replyOnce(500);

        return Api.createReleaseLink(dummyProjectPath, dummyReleaseTag, expectedLink).catch(() => {
          expect(mock.history.post).toHaveLength(1);
        });
      });
    });
  });

  describe('deleteReleaseLink', () => {
    const dummyProjectPath = 'gitlab-org/gitlab';
    const dummyReleaseTag = 'v1.3';
    const dummyLinkId = '4';
    const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/${encodeURIComponent(
      dummyProjectPath,
    )}/releases/${dummyReleaseTag}/assets/links/${dummyLinkId}`;

    describe('when the Release is successfully deleted', () => {
      it('resolves the Promise', () => {
        mock.onDelete(expectedUrl).replyOnce(200);

        return Api.deleteReleaseLink(dummyProjectPath, dummyReleaseTag, dummyLinkId).then(() => {
          expect(mock.history.delete).toHaveLength(1);
        });
      });
    });

    describe('when an error occurs while deleting the Release', () => {
      it('rejects the Promise', () => {
        mock.onDelete(expectedUrl).replyOnce(500);

        return Api.deleteReleaseLink(dummyProjectPath, dummyReleaseTag, dummyLinkId).catch(() => {
          expect(mock.history.delete).toHaveLength(1);
        });
      });
    });
  });

  describe('getRawFile', () => {
    const dummyProjectPath = 'gitlab-org/gitlab';
    const dummyFilePath = 'doc/CONTRIBUTING.md';
    const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/${encodeURIComponent(
      dummyProjectPath,
    )}/repository/files/${encodeURIComponent(dummyFilePath)}/raw`;

    describe('when the raw file is successfully fetched', () => {
      it('resolves the Promise', () => {
        mock.onGet(expectedUrl).replyOnce(200);

        return Api.getRawFile(dummyProjectPath, dummyFilePath).then(() => {
          expect(mock.history.get).toHaveLength(1);
        });
      });
    });

    describe('when an error occurs while getting a raw file', () => {
      it('rejects the Promise', () => {
        mock.onPost(expectedUrl).replyOnce(500);

        return Api.getRawFile(dummyProjectPath, dummyFilePath).catch(() => {
          expect(mock.history.get).toHaveLength(1);
        });
      });
    });
  });

  describe('createProjectMergeRequest', () => {
    const dummyProjectPath = 'gitlab-org/gitlab';
    const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/${encodeURIComponent(
      dummyProjectPath,
    )}/merge_requests`;
    const options = {
      source_branch: 'feature',
      target_branch: 'master',
      title: 'Add feature',
    };

    describe('when the merge request is successfully created', () => {
      it('resolves the Promise', () => {
        mock.onPost(expectedUrl, options).replyOnce(201);

        return Api.createProjectMergeRequest(dummyProjectPath, options).then(() => {
          expect(mock.history.post).toHaveLength(1);
        });
      });
    });

    describe('when an error occurs while getting a raw file', () => {
      it('rejects the Promise', () => {
        mock.onPost(expectedUrl).replyOnce(500);

        return Api.createProjectMergeRequest(dummyProjectPath).catch(() => {
          expect(mock.history.post).toHaveLength(1);
        });
      });
    });
  });

  describe('updateIssue', () => {
    it('update an issue with the given payload', done => {
      const projectId = 8;
      const issue = 1;
      const expectedArray = [1, 2, 3];
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/${projectId}/issues/${issue}`;
      mock.onPut(expectedUrl).reply(200, { assigneeIds: expectedArray });

      Api.updateIssue(projectId, issue, { assigneeIds: expectedArray })
        .then(({ data }) => {
          expect(data.assigneeIds).toEqual(expectedArray);
          done();
        })
        .catch(done.fail);
    });
  });

  describe('updateMergeRequest', () => {
    it('update an issue with the given payload', done => {
      const projectId = 8;
      const mergeRequest = 1;
      const expectedArray = [1, 2, 3];
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/${projectId}/merge_requests/${mergeRequest}`;
      mock.onPut(expectedUrl).reply(200, { assigneeIds: expectedArray });

      Api.updateMergeRequest(projectId, mergeRequest, { assigneeIds: expectedArray })
        .then(({ data }) => {
          expect(data.assigneeIds).toEqual(expectedArray);
          done();
        })
        .catch(done.fail);
    });
  });

  describe('tags', () => {
    it('fetches all tags of a particular project', done => {
      const query = 'dummy query';
      const options = { unused: 'option' };
      const projectId = 8;
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/${projectId}/repository/tags`;
      mock.onGet(expectedUrl).reply(200, [
        {
          name: 'test',
        },
      ]);

      Api.tags(projectId, query, options)
        .then(({ data }) => {
          expect(data.length).toBe(1);
          expect(data[0].name).toBe('test');
        })
        .then(done)
        .catch(done.fail);
    });
  });

  describe('freezePeriods', () => {
    it('fetches freezePeriods', () => {
      const projectId = 8;
      const freezePeriod = {
        id: 3,
        freeze_start: '5 4 * * *',
        freeze_end: '5 9 * 8 *',
        cron_timezone: 'America/New_York',
        created_at: '2020-07-10T05:10:35.122Z',
        updated_at: '2020-07-10T05:10:35.122Z',
      };
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/${projectId}/freeze_periods`;
      mock.onGet(expectedUrl).reply(200, [freezePeriod]);

      return Api.freezePeriods(projectId).then(({ data }) => {
        expect(data[0]).toStrictEqual(freezePeriod);
      });
    });
  });

  describe('createFreezePeriod', () => {
    const projectId = 8;
    const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/${projectId}/freeze_periods`;
    const options = {
      freeze_start: '* * * * *',
      freeze_end: '* * * * *',
      cron_timezone: 'America/Juneau',
    };

    const expectedResult = {
      id: 10,
      freeze_start: '* * * * *',
      freeze_end: '* * * * *',
      cron_timezone: 'America/Juneau',
      created_at: '2020-07-11T07:04:50.153Z',
      updated_at: '2020-07-11T07:04:50.153Z',
    };

    describe('when the freeze period is successfully created', () => {
      it('resolves the Promise', () => {
        mock.onPost(expectedUrl, options).replyOnce(201, expectedResult);

        return Api.createFreezePeriod(projectId, options).then(({ data }) => {
          expect(data).toStrictEqual(expectedResult);
        });
      });
    });
  });

  describe('createPipeline', () => {
    it('creates new pipeline', () => {
      const redirectUrl = 'ci-project/-/pipelines/95';
      const projectId = 8;
      const postData = {
        ref: 'tag-1',
        variables: [
          { key: 'test_file', value: 'test_file_val', variable_type: 'file' },
          { key: 'test_var', value: 'test_var_val', variable_type: 'env_var' },
        ],
      };
      const expectedUrl = `${dummyUrlRoot}/api/${dummyApiVersion}/projects/${projectId}/pipeline`;

      jest.spyOn(axios, 'post');

      mock.onPost(expectedUrl).replyOnce(200, {
        web_url: redirectUrl,
      });

      return Api.createPipeline(projectId, postData).then(({ data }) => {
        expect(data.web_url).toBe(redirectUrl);
        expect(axios.post).toHaveBeenCalledWith(expectedUrl, postData, {
          headers: {
            'Content-Type': 'application/json',
          },
        });
      });
    });
  });
});
