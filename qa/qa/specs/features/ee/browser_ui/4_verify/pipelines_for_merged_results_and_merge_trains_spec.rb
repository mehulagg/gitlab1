# frozen_string_literal: true

require 'faker'

module QA
  RSpec.describe 'Verify', :runner do
    describe 'Pipelines for merged results and merge trains' do
      let(:executor) { "qa-runner-#{Faker::Alphanumeric.alphanumeric(8)}" }

      let!(:runner) do
        Resource::Runner.fabricate_via_api! do |runner|
          runner.project = project
          runner.name = executor
          runner.tags = [executor]
        end
      end

      let(:project) do
        Resource::Project.fabricate_via_api! do |project|
          project.name = 'pipelines-for-merge-trains'
        end
      end

      let!(:ci_file) do
        Resource::Repository::Commit.fabricate_via_api! do |commit|
          commit.project = project
          commit.commit_message = 'Add .gitlab-ci.yml'
          commit.add_files(
            [
              {
                file_path: '.gitlab-ci.yml',
                content: <<~YAML
                  test:
                    tags: [#{executor}]
                    script: echo 'OK'
                    only:
                    - merge_requests
                YAML
              }
            ]
          )
        end
      end

      let(:merge_request) do
        Resource::MergeRequest.fabricate_via_api! do |merge_request|
          merge_request.project = project
          merge_request.description = Faker::Lorem.sentence
          merge_request.target_new_branch = false
          merge_request.file_name = Faker::Lorem.word
          merge_request.file_content = Faker::Lorem.sentence
        end
      end

      before do
        Flow::Login.sign_in
        project.visit!
        Flow::MergeRequest.enable_merge_trains
      end

      after do
        runner.remove_via_api! if runner
      end

      it 'creates a pipeline with merged results', testcase: 'https://gitlab.com/gitlab-org/quality/testcases/-/issues/562' do
        merge_request.visit!

        Page::MergeRequest::Show.perform do |show|
          expect(show).to have_pipeline_status('passed'), "Expected the merge request pipeline to pass."

          # The default option is to merge via merge train,
          # but that is covered by the 'merges via a merge train' test
          show.skip_merge_train_and_merge_immediately

          expect(show).to be_merged, "Expected content 'The changes were merged' but it did not appear."
        end
      end

      it 'merges via a merge train', testcase: 'https://gitlab.com/gitlab-org/quality/testcases/-/issues/561' do
        merge_request.visit!

        Page::MergeRequest::Show.perform do |show|
          expect(show).to have_pipeline_status('passed'), "Expected the merge request pipeline to pass."

          # Due to this behavior https://gitlab.com/gitlab-org/gitlab/-/issues/321001
          # I'm going to retry this action until the train starts
          show.retry_until(max_attempts: 3) do
            show.merge_via_merge_train
            show.wait_until(max_duration: 10, reload: false, raise_on_failure: false) { show.has_content? 'started a merge train' }
          end

          expect(show).to be_merged, "Expected content 'The changes were merged' but it did not appear."
        end
      end
    end
  end
end
