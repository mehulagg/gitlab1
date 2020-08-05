/* eslint-disable @gitlab/require-i18n-strings */
import update from 'immutability-helper';

import createFlash from '~/flash';
import { extractCurrentDiscussion, extractDesign } from './design_management_utils';
import {
  ADD_IMAGE_DIFF_NOTE_ERROR,
  ADD_DISCUSSION_COMMENT_ERROR,
  designDeletionError,
} from './error_messages';

const deleteDesignsFromStore = (store, query, selectedDesigns) => {
  const sourceData = store.readQuery(query);

  const changedDesigns = sourceData.project.issue.designCollection.designs.nodes.filter(
    node => !selectedDesigns.includes(node.filename),
  );

  const data = update(sourceData, {
    project: { issue: { designCollection: { designs: { nodes: { $set: [...changedDesigns] } } } } },
  });

  store.writeQuery({
    ...query,
    data,
  });
};

/**
 * Adds a new version of designs to store
 *
 * @param {Object} store
 * @param {Object} query
 * @param {Object} version
 */
const addNewVersionToStore = (store, query, version) => {
  if (!version) return;

  const sourceData = store.readQuery(query);

  const data = update(sourceData, {
    project: { issue: { designCollection: { versions: { nodes: { $unshift: [version] } } } } },
  });

  store.writeQuery({
    ...query,
    data,
  });
};

const addDiscussionCommentToStore = (store, createNote, query, queryVariables, discussionId) => {
  const sourceData = store.readQuery({
    query,
    variables: queryVariables,
  });

  const sourceDesign = extractDesign(sourceData);
  const sourceDiscussion = extractCurrentDiscussion(sourceDesign.discussions, discussionId);
  const discussionIndex = sourceDesign.discussions.nodes.indexOf(sourceDiscussion);
  const designIndex = sourceData.project.issue.designCollection.designs.nodes.indexOf(sourceDesign);

  const discussion = update(sourceDiscussion, { notes: { nodes: { $push: [createNote.note] } } });

  let design = update(sourceDesign, {
    discussions: { nodes: { [discussionIndex]: { $set: discussion } } },
  });

  design = update(design, {
    notesCount: { $apply: count => count + 1 },
  });

  if (
    !design.issue.participants.nodes.some(
      participant => participant.username === createNote.note.author.username,
    )
  ) {
    design = update(design, {
      issue: {
        participants: {
          nodes: {
            $push: [
              {
                __typename: 'User',
                ...createNote.note.author,
              },
            ],
          },
        },
      },
    });
  }

  const data = update(sourceData, {
    project: {
      issue: { designCollection: { designs: { nodes: { [designIndex]: { $set: design } } } } },
    },
  });

  store.writeQuery({
    query,
    variables: queryVariables,
    data,
  });
};

const addImageDiffNoteToStore = (store, createImageDiffNote, query, variables) => {
  const sourceData = store.readQuery({
    query,
    variables,
  });

  const newDiscussion = {
    __typename: 'Discussion',
    id: createImageDiffNote.note.discussion.id,
    replyId: createImageDiffNote.note.discussion.replyId,
    resolvable: true,
    resolved: false,
    resolvedAt: null,
    resolvedBy: null,
    notes: {
      __typename: 'NoteConnection',
      nodes: [createImageDiffNote.note],
    },
  };

  const sourceDesign = extractDesign(sourceData);
  const designIndex = sourceData.project.issue.designCollection.designs.nodes.indexOf(sourceDesign);

  let design = update(sourceDesign, {
    notesCount: { $apply: count => count + 1 },
  });

  design = update(design, {
    discussions: { nodes: { $push: [newDiscussion] } },
  });

  if (
    !design.issue.participants.nodes.some(
      participant => participant.username === createImageDiffNote.note.author.username,
    )
  ) {
    design = update(design, {
      issue: {
        participants: {
          nodes: {
            $push: [
              {
                __typename: 'User',
                ...createImageDiffNote.note.author,
              },
            ],
          },
        },
      },
    });
  }

  const data = update(sourceData, {
    project: {
      issue: { designCollection: { designs: { nodes: { [designIndex]: { $set: design } } } } },
    },
  });

  store.writeQuery({
    query,
    variables,
    data,
  });
};

const addNewDesignToStore = (store, designManagementUpload, query) => {
  const sourceData = store.readQuery(query);

  const newDesigns = sourceData.project.issue.designCollection.designs.nodes.reduce(
    (acc, design) => {
      if (!acc.find(d => d.filename === design.filename)) {
        acc.push(design);
      }

      return acc;
    },
    designManagementUpload.designs,
  );

  let newVersionNode;
  const findNewVersions = designManagementUpload.designs.find(design => design.versions);

  if (findNewVersions) {
    const findNewVersionsNodes = findNewVersions.versions.nodes;

    if (findNewVersionsNodes && findNewVersionsNodes.length) {
      newVersionNode = [findNewVersionsNodes[0]];
    }
  }

  const newVersions = [
    ...(newVersionNode || []),
    ...sourceData.project.issue.designCollection.versions.nodes,
  ];

  const updatedDesigns = {
    __typename: 'DesignCollection',
    designs: {
      __typename: 'DesignConnection',
      nodes: newDesigns,
    },
    versions: {
      __typename: 'DesignVersionConnection',
      nodes: newVersions,
    },
  };

  const data = update(sourceData, {
    project: { issue: { designCollection: { $set: updatedDesigns } } },
  });

  store.writeQuery({
    ...query,
    data,
  });
};

const onError = (data, message) => {
  createFlash(message);
  throw new Error(data.errors);
};

export const hasErrors = ({ errors = [] }) => errors?.length;

/**
 * Updates a store after design deletion
 *
 * @param {Object} store
 * @param {Object} data
 * @param {Object} query
 * @param {Array} designs
 */
export const updateStoreAfterDesignsDelete = (store, data, query, designs) => {
  if (hasErrors(data)) {
    onError(data, designDeletionError({ singular: designs.length === 1 }));
  } else {
    deleteDesignsFromStore(store, query, designs);
    addNewVersionToStore(store, query, data.version);
  }
};

export const updateStoreAfterAddDiscussionComment = (
  store,
  data,
  query,
  queryVariables,
  discussionId,
) => {
  if (hasErrors(data)) {
    onError(data, ADD_DISCUSSION_COMMENT_ERROR);
  } else {
    addDiscussionCommentToStore(store, data, query, queryVariables, discussionId);
  }
};

export const updateStoreAfterAddImageDiffNote = (store, data, query, queryVariables) => {
  if (hasErrors(data)) {
    onError(data, ADD_IMAGE_DIFF_NOTE_ERROR);
  } else {
    addImageDiffNoteToStore(store, data, query, queryVariables);
  }
};

export const updateStoreAfterUploadDesign = (store, data, query) => {
  if (hasErrors(data)) {
    onError(data, data.errors[0]);
  } else {
    addNewDesignToStore(store, data, query);
  }
};
