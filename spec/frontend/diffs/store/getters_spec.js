import { PARALLEL_DIFF_VIEW_TYPE, INLINE_DIFF_VIEW_TYPE } from '~/diffs/constants';
import * as getters from '~/diffs/store/getters';
import state from '~/diffs/store/modules/diff_state';
import discussion from '../mock_data/diff_discussions';

describe('Diffs Module Getters', () => {
  let localState;
  let discussionMock;
  let discussionMock1;

  const diffFileMock = {
    fileHash: '9732849daca6ae818696d9575f5d1207d1a7f8bb',
  };

  beforeEach(() => {
    localState = state();
    discussionMock = { ...discussion };
    discussionMock.diff_file.file_hash = diffFileMock.fileHash;

    discussionMock1 = { ...discussion };
    discussionMock1.diff_file.file_hash = diffFileMock.fileHash;
  });

  describe('isParallelView', () => {
    it('should return true if view set to parallel view', () => {
      localState.diffViewType = PARALLEL_DIFF_VIEW_TYPE;

      expect(getters.isParallelView(localState)).toEqual(true);
    });

    it('should return false if view not to parallel view', () => {
      localState.diffViewType = INLINE_DIFF_VIEW_TYPE;

      expect(getters.isParallelView(localState)).toEqual(false);
    });
  });

  describe('isInlineView', () => {
    it('should return true if view set to inline view', () => {
      localState.diffViewType = INLINE_DIFF_VIEW_TYPE;

      expect(getters.isInlineView(localState)).toEqual(true);
    });

    it('should return false if view not to inline view', () => {
      localState.diffViewType = PARALLEL_DIFF_VIEW_TYPE;

      expect(getters.isInlineView(localState)).toEqual(false);
    });
  });

  describe('whichCollapsedTypes', () => {
    const autoCollapsedFile = { viewer: { automaticallyCollapsed: true, manuallyCollapsed: null } };
    const manuallyCollapsedFile = {
      viewer: { automaticallyCollapsed: false, manuallyCollapsed: true },
    };
    const openFile = { viewer: { automaticallyCollapsed: false, manuallyCollapsed: false } };

    it.each`
      description                                 | value    | files
      ${'all files are automatically collapsed'}  | ${true}  | ${[{ ...autoCollapsedFile }, { ...autoCollapsedFile }]}
      ${'all files are manually collapsed'}       | ${true}  | ${[{ ...manuallyCollapsedFile }, { ...manuallyCollapsedFile }]}
      ${'no files are collapsed in any way'}      | ${false} | ${[{ ...openFile }, { ...openFile }]}
      ${'some files are collapsed in either way'} | ${true}  | ${[{ ...manuallyCollapsedFile }, { ...autoCollapsedFile }, { ...openFile }]}
    `('`any` is $value when $description', ({ value, files }) => {
      localState.diffFiles = files;

      const getterResult = getters.whichCollapsedTypes(localState);

      expect(getterResult.any).toEqual(value);
    });

    it.each`
      description                                 | value    | files
      ${'all files are automatically collapsed'}  | ${true}  | ${[{ ...autoCollapsedFile }, { ...autoCollapsedFile }]}
      ${'all files are manually collapsed'}       | ${false} | ${[{ ...manuallyCollapsedFile }, { ...manuallyCollapsedFile }]}
      ${'no files are collapsed in any way'}      | ${false} | ${[{ ...openFile }, { ...openFile }]}
      ${'some files are collapsed in either way'} | ${true}  | ${[{ ...manuallyCollapsedFile }, { ...autoCollapsedFile }, { ...openFile }]}
    `('`automatic` is $value when $description', ({ value, files }) => {
      localState.diffFiles = files;

      const getterResult = getters.whichCollapsedTypes(localState);

      expect(getterResult.automatic).toEqual(value);
    });

    it.each`
      description                                 | value    | files
      ${'all files are automatically collapsed'}  | ${false} | ${[{ ...autoCollapsedFile }, { ...autoCollapsedFile }]}
      ${'all files are manually collapsed'}       | ${true}  | ${[{ ...manuallyCollapsedFile }, { ...manuallyCollapsedFile }]}
      ${'no files are collapsed in any way'}      | ${false} | ${[{ ...openFile }, { ...openFile }]}
      ${'some files are collapsed in either way'} | ${true}  | ${[{ ...manuallyCollapsedFile }, { ...autoCollapsedFile }, { ...openFile }]}
    `('`manual` is $value when $description', ({ value, files }) => {
      localState.diffFiles = files;

      const getterResult = getters.whichCollapsedTypes(localState);

      expect(getterResult.manual).toEqual(value);
    });
  });

  describe('commitId', () => {
    it('returns commit id when is set', () => {
      const commitID = '800f7a91';
      localState.commit = {
        id: commitID,
      };

      expect(getters.commitId(localState)).toEqual(commitID);
    });

    it('returns null when no commit is set', () => {
      expect(getters.commitId(localState)).toEqual(null);
    });
  });

  describe('diffHasAllExpandedDiscussions', () => {
    it('returns true when all discussions are expanded', () => {
      expect(
        getters.diffHasAllExpandedDiscussions(localState, {
          getDiffFileDiscussions: () => [discussionMock, discussionMock],
        })(diffFileMock),
      ).toEqual(true);
    });

    it('returns false when there are no discussions', () => {
      expect(
        getters.diffHasAllExpandedDiscussions(localState, {
          getDiffFileDiscussions: () => [],
        })(diffFileMock),
      ).toEqual(false);
    });

    it('returns false when one discussions is collapsed', () => {
      discussionMock1.expanded = false;

      expect(
        getters.diffHasAllExpandedDiscussions(localState, {
          getDiffFileDiscussions: () => [discussionMock, discussionMock1],
        })(diffFileMock),
      ).toEqual(false);
    });
  });

  describe('diffHasAllCollapsedDiscussions', () => {
    it('returns true when all discussions are collapsed', () => {
      discussionMock.diff_file.file_hash = diffFileMock.fileHash;
      discussionMock.expanded = false;

      expect(
        getters.diffHasAllCollapsedDiscussions(localState, {
          getDiffFileDiscussions: () => [discussionMock],
        })(diffFileMock),
      ).toEqual(true);
    });

    it('returns false when there are no discussions', () => {
      expect(
        getters.diffHasAllCollapsedDiscussions(localState, {
          getDiffFileDiscussions: () => [],
        })(diffFileMock),
      ).toEqual(false);
    });

    it('returns false when one discussions is expanded', () => {
      discussionMock1.expanded = false;

      expect(
        getters.diffHasAllCollapsedDiscussions(localState, {
          getDiffFileDiscussions: () => [discussionMock, discussionMock1],
        })(diffFileMock),
      ).toEqual(false);
    });
  });

  describe('diffHasExpandedDiscussions', () => {
    it('returns true when one of the discussions is expanded', () => {
      const diffFile = {
        parallel_diff_lines: [],
        highlighted_diff_lines: [
          {
            discussions: [discussionMock, discussionMock],
            discussionsExpanded: true,
          },
        ],
      };

      expect(getters.diffHasExpandedDiscussions(localState)(diffFile)).toEqual(true);
    });

    it('returns false when there are no discussions', () => {
      const diffFile = {
        parallel_diff_lines: [],
        highlighted_diff_lines: [
          {
            discussions: [],
            discussionsExpanded: true,
          },
        ],
      };
      expect(getters.diffHasExpandedDiscussions(localState)(diffFile)).toEqual(false);
    });

    it('returns false when no discussion is expanded', () => {
      const diffFile = {
        parallel_diff_lines: [],
        highlighted_diff_lines: [
          {
            discussions: [discussionMock, discussionMock],
            discussionsExpanded: false,
          },
        ],
      };

      expect(getters.diffHasExpandedDiscussions(localState)(diffFile)).toEqual(false);
    });
  });

  describe('diffHasDiscussions', () => {
    it('returns true when getDiffFileDiscussions returns discussions', () => {
      const diffFile = {
        parallel_diff_lines: [],
        highlighted_diff_lines: [
          {
            discussions: [discussionMock, discussionMock],
            discussionsExpanded: false,
          },
        ],
      };

      expect(getters.diffHasDiscussions(localState)(diffFile)).toEqual(true);
    });

    it('returns false when getDiffFileDiscussions returns no discussions', () => {
      const diffFile = {
        parallel_diff_lines: [],
        highlighted_diff_lines: [
          {
            discussions: [],
            discussionsExpanded: false,
          },
        ],
      };

      expect(getters.diffHasDiscussions(localState)(diffFile)).toEqual(false);
    });
  });

  describe('getDiffFileDiscussions', () => {
    it('returns an array with discussions when fileHash matches and the discussion belongs to a diff', () => {
      discussionMock.diff_file.file_hash = diffFileMock.file_hash;

      expect(
        getters.getDiffFileDiscussions(
          localState,
          {},
          {},
          { discussions: [discussionMock] },
        )(diffFileMock).length,
      ).toEqual(1);
    });

    it('returns an empty array when no discussions are found in the given diff', () => {
      expect(
        getters.getDiffFileDiscussions(localState, {}, {}, { discussions: [] })(diffFileMock)
          .length,
      ).toEqual(0);
    });
  });

  describe('getDiffFileByHash', () => {
    it('returns file by hash', () => {
      const fileA = {
        file_hash: '123',
      };
      const fileB = {
        file_hash: '456',
      };
      localState.diffFiles = [fileA, fileB];

      expect(getters.getDiffFileByHash(localState)('456')).toEqual(fileB);
    });

    it('returns null if no matching file is found', () => {
      localState.diffFiles = [];

      expect(getters.getDiffFileByHash(localState)('123')).toBeUndefined();
    });
  });

  describe('allBlobs', () => {
    it('returns an array of blobs', () => {
      localState.treeEntries = {
        file: {
          type: 'blob',
          path: 'file',
          parentPath: '/',
          tree: [],
        },
        tree: {
          type: 'tree',
          path: 'tree',
          parentPath: '/',
          tree: [],
        },
      };

      expect(
        getters.allBlobs(localState, {
          flatBlobsList: getters.flatBlobsList(localState),
        }),
      ).toEqual([
        {
          isHeader: true,
          path: '/',
          tree: [
            {
              parentPath: '/',
              path: 'file',
              tree: [],
              type: 'blob',
            },
          ],
        },
      ]);
    });
  });

  describe('currentDiffIndex', () => {
    it('returns index of currently selected diff in diffList', () => {
      localState.diffFiles = [{ file_hash: '111' }, { file_hash: '222' }, { file_hash: '333' }];
      localState.currentDiffFileId = '222';

      expect(getters.currentDiffIndex(localState)).toEqual(1);

      localState.currentDiffFileId = '333';

      expect(getters.currentDiffIndex(localState)).toEqual(2);
    });

    it('returns 0 if no diff is selected yet or diff is not found', () => {
      localState.diffFiles = [{ file_hash: '111' }, { file_hash: '222' }, { file_hash: '333' }];
      localState.currentDiffFileId = '';

      expect(getters.currentDiffIndex(localState)).toEqual(0);
    });
  });

  describe('fileLineCoverage', () => {
    beforeEach(() => {
      Object.assign(localState.coverageFiles, { files: { 'app.js': { 1: 0, 2: 5 } } });
    });

    it('returns empty object when no coverage data is available', () => {
      Object.assign(localState.coverageFiles, {});

      expect(getters.fileLineCoverage(localState)('test.js', 2)).toEqual({});
    });

    it('returns empty object when unknown filename is passed', () => {
      expect(getters.fileLineCoverage(localState)('test.js', 2)).toEqual({});
    });

    it('returns no-coverage info when correct filename and line is passed', () => {
      expect(getters.fileLineCoverage(localState)('app.js', 1)).toEqual({
        text: 'No test coverage',
        class: 'no-coverage',
      });
    });

    it('returns coverage info when correct filename and line is passed', () => {
      expect(getters.fileLineCoverage(localState)('app.js', 2)).toEqual({
        text: 'Test coverage: 5 hits',
        class: 'coverage',
      });
    });
  });

  describe('fileCodequalityDiff', () => {
    beforeEach(() => {
      Object.assign(localState.codequalityDiff, {
        files: { 'app.js': [{ line: 1, description: 'Unexpected alert.', severity: 'minor' }] },
      });
    });

    it('returns empty array when no codequality data is available', () => {
      Object.assign(localState.codequalityDiff, {});

      expect(getters.fileCodequalityDiff(localState)('test.js')).toEqual([]);
    });

    it('returns array when codequality data is available for given file', () => {
      expect(getters.fileCodequalityDiff(localState)('app.js')).toEqual([
        { line: 1, description: 'Unexpected alert.', severity: 'minor' },
      ]);
    });
  });

  describe('suggestionCommitMessage', () => {
    let rootState;

    beforeEach(() => {
      Object.assign(localState, {
        defaultSuggestionCommitMessage:
          '%{branch_name}%{project_path}%{project_name}%{username}%{user_full_name}%{file_paths}%{suggestions_count}%{files_count}',
      });
      rootState = {
        page: {
          mrMetadata: {
            branch_name: 'branch',
            project_path: '/path',
            project_name: 'name',
            username: 'user',
            user_full_name: 'user userton',
          },
        },
      };
    });

    it.each`
      specialState                | output
      ${{}}                       | ${'branch/pathnameuseruser userton%{file_paths}%{suggestions_count}%{files_count}'}
      ${{ user_full_name: null }} | ${'branch/pathnameuser%{user_full_name}%{file_paths}%{suggestions_count}%{files_count}'}
      ${{ username: null }}       | ${'branch/pathname%{username}user userton%{file_paths}%{suggestions_count}%{files_count}'}
      ${{ project_name: null }}   | ${'branch/path%{project_name}useruser userton%{file_paths}%{suggestions_count}%{files_count}'}
      ${{ project_path: null }}   | ${'branch%{project_path}nameuseruser userton%{file_paths}%{suggestions_count}%{files_count}'}
      ${{ branch_name: null }}    | ${'%{branch_name}/pathnameuseruser userton%{file_paths}%{suggestions_count}%{files_count}'}
    `(
      'provides the correct "base" default commit message based on state ($specialState)',
      ({ specialState, output }) => {
        Object.assign(rootState.page.mrMetadata, specialState);

        expect(getters.suggestionCommitMessage(localState, null, rootState)()).toBe(output);
      },
    );

    it.each`
      stateOverrides              | output
      ${{}}                       | ${'branch/pathnameuseruser userton%{file_paths}%{suggestions_count}%{files_count}'}
      ${{ user_full_name: null }} | ${'branch/pathnameuser%{user_full_name}%{file_paths}%{suggestions_count}%{files_count}'}
      ${{ username: null }}       | ${'branch/pathname%{username}user userton%{file_paths}%{suggestions_count}%{files_count}'}
      ${{ project_name: null }}   | ${'branch/path%{project_name}useruser userton%{file_paths}%{suggestions_count}%{files_count}'}
      ${{ project_path: null }}   | ${'branch%{project_path}nameuseruser userton%{file_paths}%{suggestions_count}%{files_count}'}
      ${{ branch_name: null }}    | ${'%{branch_name}/pathnameuseruser userton%{file_paths}%{suggestions_count}%{files_count}'}
    `(
      "properly overrides state values ($stateOverrides) if they're provided",
      ({ stateOverrides, output }) => {
        expect(getters.suggestionCommitMessage(localState, null, rootState)(stateOverrides)).toBe(
          output,
        );
      },
    );

    it.each`
      providedValues                                                          | output
      ${{ file_paths: 'path1, path2', suggestions_count: 1, files_count: 1 }} | ${'branch/pathnameuseruser usertonpath1, path211'}
      ${{ suggestions_count: 1, files_count: 1 }}                             | ${'branch/pathnameuseruser userton%{file_paths}11'}
      ${{ file_paths: 'path1, path2', files_count: 1 }}                       | ${'branch/pathnameuseruser usertonpath1, path2%{suggestions_count}1'}
      ${{ file_paths: 'path1, path2', suggestions_count: 1 }}                 | ${'branch/pathnameuseruser usertonpath1, path21%{files_count}'}
      ${{ something_unused: 'CrAzY TeXt' }}                                   | ${'branch/pathnameuseruser userton%{file_paths}%{suggestions_count}%{files_count}'}
    `(
      "fills in any missing interpolations ($providedValues) when they're provided at the getter callsite",
      ({ providedValues, output }) => {
        expect(getters.suggestionCommitMessage(localState, null, rootState)(providedValues)).toBe(
          output,
        );
      },
    );
  });
});
