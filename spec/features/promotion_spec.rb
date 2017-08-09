require 'spec_helper'

describe 'Promotions', js: true do
  let(:admin) { create(:admin) }
  let(:user) { create(:user) }
  let(:otherdeveloper) { create(:user, name: 'TheOtherDeveloper') }
  let(:project) { create(:project, :repository) }
  let(:milestone) { create(:milestone, project: project, start_date: Date.today, due_date: 7.days.from_now) }
  let(:otherproject) { create(:project, :repository, namespace: otherdeveloper.namespace) }  

  describe 'if you have a license' do
    before do
      project.team << [user, :master]
    end

    it 'should show no promotion at all' do
      sign_in(user)
      visit edit_project_path(project)
      expect(page).not_to have_selector('#promote_service_desk')
    end
  end

  describe 'for project features in general on premise' do
    context 'no license installed' do
      before do
        License.destroy_all
        stub_application_setting(check_namespace_plan: false)
        project.team << [user, :master]
      end

      it 'should have the contact admin line' do
        sign_in(user)
        visit edit_project_path(project)
        expect(find('#promote_service_desk')).to have_content 'Contact your Administrator to upgrade your license.'
      end
      
      it 'should have the start trial button' do
        sign_in(admin)
        visit edit_project_path(project)
        expect(find('#promote_service_desk')).to have_content 'Start GitLab Enterprise Edition trial'
      end
    end
  end

  describe 'for project features in general', js: true do
    context 'for .com' do
      before do
        project.team << [user, :master]
        otherproject.team << [user, :master]
        
        stub_application_setting(check_namespace_plan: true)
        allow(Gitlab).to receive(:com?) { true }

        sign_in(user)
      end

      it 'should have the Upgrade your plan button' do        
        visit edit_project_path(project)
        expect(find('#promote_service_desk')).to have_content 'Upgrade your plan'
      end

      it 'should have the contact owner line' do
        visit edit_project_path(otherproject)
        expect(find('#promote_service_desk')).to have_content 'Contact owner'
      end
    end
  end

  describe 'for service desk', js: true do
    let!(:license) { nil }
    
    before do
      sign_in(user)
    end

    it 'should appear in project edit page' do
      visit edit_project_path(project)
      expect(find('#promote_service_desk')).to have_content 'Improve customer support with GitLab Service Desk.'
      expect(find('#promote_service_desk')).to have_content 'GitLab Service Desk is a simple way to allow people to create issues in your GitLab instance without needing their own user account.'
    end

    it 'does not show when cookie is set' do
      visit edit_project_path(project)

      within('#promote_service_desk') do
        find('.close').trigger('click')
      end

      visit edit_project_path(project)

      expect(page).not_to have_selector('#promote_service_desk')
    end
  end

  describe 'for merge request improve', js: true do
    let!(:license) { nil }
    
    before do
      sign_in(user)
    end

    it 'should appear in project edit page' do
      visit edit_project_path(project)
      expect(find('#promote_mr_approval')).to have_content 'Improve Merge Request and customer support'
      expect(find('#promote_mr_approval')).to have_content 'Merge request approvals allow you to set the number of necessary approvals and predefine a list of approvers that will need to approve every merge request in a project.'
    end

    it 'does not show when cookie is set' do
      visit edit_project_path(project)

      within('#promote_mr_approval') do
        find('.close').trigger('click')
      end

      visit edit_project_path(project)

      expect(page).not_to have_selector('#promote_mr_approval')
    end
  end

  describe 'for repository features', js: true do
    let!(:license) { nil }
    
    before do
      sign_in(user)
    end

    it 'should appear in repository settings page' do
      visit project_settings_repository_path(project)
      
      expect(find('#promote_repository_features')).to have_content 'Improve repositories with GitLab Enterprise Edition'
      expect(find('#promote_repository_features')).to have_content 'Push Rules are defined per project so you can have different rules applied to different projects depends on your needs.'
    end

    it 'does not show when cookie is set' do
      visit project_settings_repository_path(project)

      within('#promote_repository_features') do
        find('.close').trigger('click')
      end

      visit project_settings_repository_path(project)

      expect(page).not_to have_selector('#promote_repository_features')
    end
  end

  describe 'for squash commits', js: true do
    let!(:license) { nil }
    
    before do
      sign_in(user)
    end

    it 'should appear in new MR page' do
      visit project_new_merge_request_path(project, merge_request: { target_branch: 'master', source_branch: 'feature' })
      expect(find('#promote_squash_commits')).to have_content 'Improve Merge Requests with squash commit'
      expect(find('#promote_squash_commits')).to have_content 'Squashing lets you tidy up the commit history of a branch when accepting a merge request.'
    end

    it 'does not show when cookie is set' do
      visit project_new_merge_request_path(project, merge_request: { target_branch: 'master', source_branch: 'feature' })

      within('#promote_squash_commits') do
        find('.close').trigger('click')
      end

      visit project_new_merge_request_path(project, merge_request: { target_branch: 'master', source_branch: 'feature' })

      expect(page).not_to have_selector('#promote_squash_commits')
    end
  end

  describe 'for burndown charts', js: true do
    let!(:license) { nil }
    
    before do
      sign_in(user)
    end

    it 'should appear in milestone page' do
      visit project_milestone_path(project, milestone)
      expect(find('#promote_burndown_charts')).to have_content 'Improve milestone with Burndown Charts.'
      expect(find('#promote_burndown_charts')).to have_content 'Burndown Charts are visual representations of the progress of completing a milestone.'
    end

    it 'does not show when cookie is set' do
      visit project_milestone_path(project, milestone)

      within('#promote_burndown_charts') do
        find('.close').trigger('click')
      end

      visit project_milestone_path(project, milestone)

      expect(page).not_to have_selector('#promote_burndown_charts')
    end
  end

  describe 'for issue export', js: true do
    let!(:license) { nil }
    
    before do
      sign_in(user)
    end

    it 'should appear on export modal' do
      visit project_issues_path(project)
      click_on 'Export as CSV'
      expect(find('.issues-export-modal')).to have_content 'Export issues with GitLab Enterprise Edition'
      expect(find('.issues-export-modal')).to have_content 'Export Issues to CSV enables you and your team to export all the data collected from issues into a comma-separated values (CSV) file'
    end
  end

  describe 'for project audit events', js: true do
    let!(:license) { nil }
    
    before do
      sign_in(user)
    end

    it 'should appear on the page' do
      visit project_audit_events_path(project)
      expect(find('.user-callout-copy')).to have_content 'Track your project with Audit Events'
      expect(find('.user-callout-copy')).to have_content 'Audit Events is a tool for GitLab Enterprise Edition administrators to be able to track important events such as user access level, target user, and user addition or removal.'
    end
  end

  describe 'for group contribution analytics', js: true do
    let!(:license) { nil }
    
    before do
      sign_in(user)
    end

    it 'should appear on the page' do
      visit group_analytics_path(project)
      expect(find('.user-callout-copy')).to have_content 'Track activity with Contribution analytics and GitLab Enterprise Edition.'
      expect(find('.user-callout-copy')).to have_content 'Audit Events is a tool for GitLab Enterprise Edition administrators to be able to track important events such as user access level, target user, and user addition or removal.'
    end
  end



end
