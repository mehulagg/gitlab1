# frozen_string_literal: true

require 'spec_helper'

RSpec.describe MergeRequestPollCachedWidgetEntity do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:project, refind: true)  { create :project, :repository }
  let_it_be(:resource, refind: true) { create(:merge_request, source_project: project, target_project: project) }
  let_it_be(:user)     { create(:user) }
  let(:pipeline) { create(:ci_empty_pipeline, project: project) }

  let(:request) { double('request', current_user: user, project: project) }

  subject do
    described_class.new(resource, request: request).as_json
  end

  it 'has the latest sha of the target branch' do
    is_expected.to include(:target_branch_sha)
  end

  it 'has public_merge_status as merge_status' do
    expect(resource).to receive(:public_merge_status).and_return('checking')

    expect(subject[:merge_status]).to eq 'checking'
  end

  it 'has blob path data' do
    allow(resource).to receive_messages(
      base_pipeline: pipeline,
      head_pipeline: pipeline
    )

    expect(subject).to include(:blob_path)
    expect(subject[:blob_path]).to include(:base_path)
    expect(subject[:blob_path]).to include(:head_path)
  end

  describe 'diverged_commits_count' do
    context 'when MR open and its diverging' do
      it 'returns diverged commits count' do
        allow(resource).to receive_messages(open?: true, diverged_from_target_branch?: true,
                                            diverged_commits_count: 10)

        expect(subject[:diverged_commits_count]).to eq(10)
      end
    end

    context 'when MR is not open' do
      it 'returns 0' do
        allow(resource).to receive_messages(open?: false)

        expect(subject[:diverged_commits_count]).to be_zero
      end
    end

    context 'when MR is not diverging' do
      it 'returns 0' do
        allow(resource).to receive_messages(open?: true, diverged_from_target_branch?: false)

        expect(subject[:diverged_commits_count]).to be_zero
      end
    end
  end

  describe 'diff_head_sha' do
    before do
      allow(resource).to receive(:diff_head_sha) { 'sha' }
    end

    context 'when diff head commit is empty' do
      it 'returns nil' do
        allow(resource).to receive(:diff_head_sha) { '' }

        expect(subject[:diff_head_sha]).to be_nil
      end
    end

    context 'when diff head commit present' do
      it 'returns diff head commit short id' do
        expect(subject[:diff_head_sha]).to eq('sha')
      end
    end
  end

  describe 'metrics' do
    context 'when metrics record exists with merged data' do
      before do
        resource.mark_as_merged!
        resource.metrics.update!(merged_by: user)
      end

      it 'matches merge request metrics schema' do
        expect(subject[:metrics].with_indifferent_access)
          .to match_schema('entities/merge_request_metrics')
      end

      it 'returns values from metrics record' do
        expect(subject.dig(:metrics, :merged_by, :id))
          .to eq(resource.metrics.merged_by_id)
      end
    end

    context 'when metrics record exists with closed data' do
      before do
        resource.close!
        resource.metrics.update!(latest_closed_by: user)
      end

      it 'matches merge request metrics schema' do
        expect(subject[:metrics].with_indifferent_access)
          .to match_schema('entities/merge_request_metrics')
      end

      it 'returns values from metrics record' do
        expect(subject.dig(:metrics, :closed_by, :id))
          .to eq(resource.metrics.latest_closed_by_id)
      end
    end

    context 'when metrics does not exists' do
      before do
        resource.mark_as_merged!
        resource.metrics.destroy!
        resource.reload
      end

      context 'when events exists' do
        let!(:closed_event) { create(:event, :closed, project: project, target: resource) }
        let!(:merge_event) { create(:event, :merged, project: project, target: resource) }

        it 'matches merge request metrics schema' do
          expect(subject[:metrics].with_indifferent_access)
            .to match_schema('entities/merge_request_metrics')
        end

        it 'returns values from events record' do
          expect(subject.dig(:metrics, :merged_by, :id))
            .to eq(merge_event.author_id)

          expect(subject.dig(:metrics, :closed_by, :id))
            .to eq(closed_event.author_id)

          expect(subject.dig(:metrics, :merged_at).to_s)
            .to eq(merge_event.updated_at.to_s)

          expect(subject.dig(:metrics, :closed_at).to_s)
            .to eq(closed_event.updated_at.to_s)
        end
      end

      context 'when events does not exists' do
        it 'matches merge request metrics schema' do
          expect(subject[:metrics].with_indifferent_access)
            .to match_schema('entities/merge_request_metrics')
        end
      end
    end
  end

  describe 'commits_without_merge_commits' do
    def find_matching_commit(short_id)
      resource.commits.find { |c| c.short_id == short_id }
    end

    it 'does not include merge commits' do
      commits_in_widget = subject[:commits_without_merge_commits]

      expect(commits_in_widget.length).to be < resource.commits.length
      expect(commits_in_widget.length).to eq(resource.commits.without_merge_commits.length)
      commits_in_widget.each do |c|
        expect(find_matching_commit(c[:short_id]).merge_commit?).to eq(false)
      end
    end
  end

  describe 'auto merge' do
    context 'when auto merge is enabled' do
      let(:resource) { create(:merge_request, :merge_when_pipeline_succeeds) }

      it 'returns auto merge related information' do
        expect(subject[:auto_merge_enabled]).to be_truthy
      end
    end

    context 'when auto merge is not enabled' do
      it 'returns auto merge related information' do
        expect(subject[:auto_merge_enabled]).to be_falsy
      end
    end
  end

  describe 'squash defaults for projects' do
    where(:squash_option, :value, :default, :readonly) do
      'always'      | true  | true  | true
      'never'       | false | false | true
      'default_on'  | false | true  | false
      'default_off' | false | false | false
    end

    with_them do
      before do
        project.project_setting.update!(squash_option: squash_option)
      end

      it 'the key reflects the correct value' do
        expect(subject[:squash_on_merge]).to eq(value)
        expect(subject[:squash_enabled_by_default]).to eq(default)
        expect(subject[:squash_readonly]).to eq(readonly)
      end
    end
  end

  describe 'attributes for squash commit message' do
    context 'when merge request is mergeable' do
      before do
        stub_const('MergeRequestDiff::COMMITS_SAFE_SIZE', 20)
      end

      it 'has default_squash_commit_message and commits_without_merge_commits' do
        expect(subject[:default_squash_commit_message])
          .to eq(resource.default_squash_commit_message)
        expect(subject[:commits_without_merge_commits].size).to eq(12)
      end
    end
  end

  describe 'pipeline' do
    let_it_be(:pipeline) { create(:ci_empty_pipeline, project: project, ref: resource.source_branch, sha: resource.source_branch_sha, head_pipeline_of: resource) }

    before do
      allow_any_instance_of(MergeRequestPresenter).to receive(:can?).and_call_original
      allow_any_instance_of(MergeRequestPresenter).to receive(:can?).with(user, :read_pipeline, anything).and_return(can_access)
    end

    context 'when user has access to pipelines' do
      let(:can_access) { true }

      context 'when is up to date' do
        let(:req) { double('request', current_user: user, project: project) }

        it 'returns pipeline' do
          pipeline_payload =
            MergeRequests::PipelineEntity
              .represent(pipeline, request: req)
              .as_json

          expect(subject[:pipeline]).to eq(pipeline_payload)
        end
      end

      context 'when user does not have access to pipelines' do
        let(:can_access) { false }
        let(:req) { double('request', current_user: user, project: project) }

        it 'does not have pipeline' do
          expect(subject[:pipeline]).to eq(nil)
        end
      end

      context 'when is not up to date' do
        it 'returns nil' do
          pipeline.update!(sha: "not up to date")

          expect(subject[:pipeline]).to eq(nil)
        end
      end
    end
  end
end
