# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'issues canonical link' do
  include Spec::Support::Helpers::Features::CanonicalLinkHelpers

  let_it_be(:original_project) { create(:project, :public) }
  let_it_be(:original_issue)   { create(:issue, project: original_project) }
  let_it_be(:canonical_issue)  { create(:issue) }
  let_it_be(:canonical_url)    { issue_url(canonical_issue, Gitlab::Application.routes.default_url_options) }

  it "shows the canonical URL for the original issue" do
    visit(issue_path(original_issue))

    expect(page).to have_any_canonical_links(original_issue)
  end

  context 'when the issue was moved' do
    it 'shows the canonical URL' do
      original_issue.moved_to = canonical_issue
      original_issue.save!

      visit(issue_path(original_issue))

      expect(page).to have_canonical_link(canonical_url)
    end
  end

  context 'when the issue was duplicated' do
    it 'shows the canonical URL' do
      original_issue.duplicated_to = canonical_issue
      original_issue.save!

      visit(issue_path(original_issue))

      expect(page).to have_canonical_link(canonical_url)
    end
  end
end
