# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'User reverts a commit', :js do
  include RepoHelpers

  let_it_be(:user) { create(:user) }
  let(:project) { create(:project, :repository, namespace: user.namespace) }

  before do
    sign_in(user)

    visit(project_commit_path(project, sample_commit.id))
  end

  def revert_commit(create_merge_request: false)
    find('.header-action-buttons .dropdown').click
    find('[data-testid="revert-commit-link"]').click

    page.within('[data-testid="modal-commit"]') do
      uncheck('create_merge_request') unless create_merge_request
      click_button('Revert')
    end
  end

  context 'without creating a new merge request' do
    it 'reverts a commit' do
      revert_commit

      expect(page).to have_content('The commit has been successfully reverted.')
    end

    it 'does not revert a previously reverted commit' do
      revert_commit
      # Visit the comment again once it was reverted.
      visit project_commit_path(project, sample_commit.id)

      revert_commit

      expect(page).to have_content('Sorry, we cannot revert this commit automatically.')
    end
  end

  context 'with creating a new merge request' do
    it 'reverts a commit' do
      revert_commit(create_merge_request: true)

      expect(page).to have_content('The commit has been successfully reverted. You can now submit a merge request to get this change into the original branch.')
      expect(page).to have_content("From revert-#{Commit.truncate_sha(sample_commit.id)} into master")
    end
  end

  context 'when the project is archived' do
    let(:project) { create(:project, :repository, :archived, namespace: user.namespace) }

    it 'does not show the revert link' do
      find('.header-action-buttons .dropdown').click

      expect(page).not_to have_link('Revert')
    end
  end
end
