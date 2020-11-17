# frozen_string_literal: true
require 'spec_helper'

RSpec.describe DraftNotes::CreateService do
  let(:merge_request) { create(:merge_request) }
  let(:project) { merge_request.target_project }
  let(:user) { merge_request.author }

  def create_draft(params)
    described_class.new(merge_request, user, params).execute
  end

  it 'creates a simple draft note' do
    draft = create_draft(note: 'This is a test')

    expect(draft).to be_an_instance_of(DraftNote)
    expect(draft.note).to eq('This is a test')
    expect(draft.author).to eq(user)
    expect(draft.project).to eq(merge_request.target_project)
    expect(draft.discussion_id).to be_nil
  end

  it 'cannot resolve when there is nothing to resolve' do
    draft = create_draft(note: 'Not a reply!', resolve_discussion: true)

    expect(draft.errors[:base]).to include('User is not allowed to resolve thread')
    expect(draft).not_to be_persisted
  end

  context 'in a thread' do
    it 'creates a draft note with discussion_id' do
      discussion = create(:discussion_note_on_merge_request, noteable: merge_request, project: project).discussion

      draft = create_draft(note: 'A reply!', in_reply_to_discussion_id: discussion.reply_id)

      expect(draft.note).to eq('A reply!')
      expect(draft.discussion_id).to eq(discussion.reply_id)
      expect(draft.resolve_discussion).to be_falsey
    end

    it 'creates a draft that resolves the thread' do
      discussion = create(:discussion_note_on_merge_request, noteable: merge_request, project: project).discussion

      draft = create_draft(note: 'A reply!', in_reply_to_discussion_id: discussion.reply_id, resolve_discussion: true)

      expect(draft.note).to eq('A reply!')
      expect(draft.discussion_id).to eq(discussion.reply_id)
      expect(draft.resolve_discussion).to be true
    end
  end

  it 'creates a draft note with a position in a diff' do
    diff_refs = project.commit(RepoHelpers.sample_commit.id).try(:diff_refs)

    position = Gitlab::Diff::Position.new(
      old_path: "files/ruby/popen.rb",
      new_path: "files/ruby/popen.rb",
      old_line: nil,
      new_line: 14,
      diff_refs: diff_refs
    )

    draft = create_draft(note: 'Comment on diff', position: position.to_json)

    expect(draft.note).to eq('Comment on diff')
    expect(draft.original_position.to_json).to eq(position.to_json)
  end

  context 'diff highlight cache clearing' do
    context 'when diff file is unfolded and it is not a reply' do
      it 'clears diff highlighting cache' do
        expect_next_instance_of(DraftNote) do |draft|
          allow(draft).to receive_message_chain(:diff_file, :unfolded?) { true }
        end

        expect(merge_request).to receive_message_chain(:diffs, :clear_cache)

        create_draft(note: 'This is a test')
      end
    end

    context 'when diff file is not unfolded and it is not a reply' do
      it 'clears diff highlighting cache' do
        expect_next_instance_of(DraftNote) do |draft|
          allow(draft).to receive_message_chain(:diff_file, :unfolded?) { false }
        end

        expect(merge_request).not_to receive(:diffs)

        create_draft(note: 'This is a test')
      end
    end
  end
end
