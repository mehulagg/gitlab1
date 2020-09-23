# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Projects > Snippets > Project snippet', :js do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) do
    create(:project, creator: user).tap do |p|
      p.add_maintainer(user)
    end
  end

  let_it_be(:snippet) { create(:project_snippet, :repository, project: project, author: user) }

  before do
    stub_feature_flags(snippets_vue: false)

    sign_in(user)
  end

  it_behaves_like 'show and render proper snippet blob' do
    let(:anchor) { nil }

    subject do
      visit project_snippet_path(project, snippet, anchor: anchor)

      wait_for_requests
    end
  end

  it_behaves_like 'showing user status' do
    let(:file_path) { 'files/ruby/popen.rb' }
    let(:user_with_status) { snippet.author }

    subject { visit project_snippet_path(project, snippet) }
  end

  it_behaves_like 'does not show New Snippet button' do
    let(:file_path) { 'files/ruby/popen.rb' }

    subject { visit project_snippet_path(project, snippet) }
  end
end
