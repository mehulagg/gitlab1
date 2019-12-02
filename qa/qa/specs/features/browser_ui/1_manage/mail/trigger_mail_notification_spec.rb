# frozen_string_literal: true

module QA
  context 'Manage', :orchestrated, :smtp do
    describe 'mail notification' do
      let(:user) do
        Resource::User.fabricate_or_use(Runtime::Env.gitlab_qa_username_1, Runtime::Env.gitlab_qa_password_1)
      end

      let(:project) do
        Resource::Project.fabricate_via_api! do |resource|
          resource.name = 'email-notification-test'
        end
      end

      before do
        Runtime::Browser.visit(:gitlab, Page::Main::Login)
        Page::Main::Login.perform(&:sign_in_using_credentials)

        project.visit!
      end

      it 'user receives email for project invitation' do
        Page::Project::Menu.perform(&:go_to_members_settings)
        Page::Project::Settings::Members.perform do |member_settings|
          member_settings.add_member(user.username)
        end

        expect(page).to have_content(/@#{user.username}(\n| )?Given access/)

        # Wait for Action Mailer to deliver messages
        mailhog_json = Support::Retrier.retry_until(sleep_interval: 1) do
          Runtime::Logger.debug(%Q[retrieving "#{QA::Runtime::MailHog.api_messages_url}"]) if Runtime::Env.debug?

          mailhog_response = get QA::Runtime::MailHog.api_messages_url

          mailhog_data = JSON.parse(mailhog_response.body)

          # Expect at least two invitation messages: group and project
          mailhog_data if mailhog_data.dig('total') >= 2
        end

        # Check json result from mailhog
        mailhog_items = mailhog_json.dig('items')
        expect(mailhog_items).to include(an_object_satisfying { |o| /project was granted/ === o.dig('Content', 'Headers', 'Subject', 0) })
      end
    end
  end
end
