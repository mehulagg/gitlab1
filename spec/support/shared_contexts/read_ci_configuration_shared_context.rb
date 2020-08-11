# frozen_string_literal: true

RSpec.shared_context 'read ci configuration for sast enabled project' do
  let_it_be(:gitlab_ci_yml_content) do
    File.read(Rails.root.join('spec/support/gitlab_stubs/gitlab_ci_for_sast.yml'))
  end

  let_it_be(:project) { create(:project, :repository) }

  before do
    allow_any_instance_of(Repository).to receive(:gitlab_ci_yml_for).and_return(gitlab_ci_yml_content)
  end
end
