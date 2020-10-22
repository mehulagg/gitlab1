# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Invitations do
  let(:maintainer) { create(:user, username: 'maintainer_user') }
  let(:developer) { create(:user) }
  let(:access_requester) { create(:user) }
  let(:stranger) { create(:user) }
  let(:email) { 'email@example.org' }

  let(:project) do
    create(:project, :public, creator_id: maintainer.id, namespace: maintainer.namespace) do |project|
      project.add_developer(developer)
      project.add_maintainer(maintainer)
      project.request_access(access_requester)
    end
  end

  let!(:group) do
    create(:group, :public) do |group|
      group.add_developer(developer)
      group.add_owner(maintainer)
      group.request_access(access_requester)
    end
  end

  def invitations_url(source, user)
    api("/#{source.model_name.plural}/#{source.id}/invitations", user)
  end

  shared_examples 'POST /:source_type/:id/invitations' do |source_type|
    context "with :source_type == #{source_type.pluralize}" do
      it_behaves_like 'a 404 response when source is private' do
        let(:route) do
          post invitations_url(source, stranger),
               params: { email: email, access_level: Member::MAINTAINER }
        end
      end

      context 'when authenticated as a non-member or member with insufficient rights' do
        %i[access_requester stranger developer].each do |type|
          context "as a #{type}" do
            it 'returns 403' do
              user = public_send(type)

              post invitations_url(source, user), params: { email: email, access_level: Member::MAINTAINER }

              expect(response).to have_gitlab_http_status(:forbidden)
            end
          end
        end
      end

      context 'when authenticated as a maintainer/owner' do
        context 'and new member is already a requester' do
          it 'does not transform the requester into a proper member' do
            expect do
              post api("/#{source_type.pluralize}/#{source.id}/invitations", maintainer),
                   params: { email: email, access_level: Member::MAINTAINER }

              expect(response).to have_gitlab_http_status(:created)
            end.not_to change { source.members.count }
            expect(json_response['user_id']).to eq(nil)
            expect(json_response['invite_email']).to eq(email)
            expect(json_response['invite_token']).not_to eq(nil)
            expect(json_response['access_level']).to eq(Member::MAINTAINER)
          end
        end

        it 'invites a new member' do
          expect do
            post api("/#{source_type.pluralize}/#{source.id}/invitations", maintainer),
                 params: { email: email, access_level: Member::DEVELOPER }

            expect(response).to have_gitlab_http_status(:created)
          end.to change { source.requesters.count }.by(1)
          expect(json_response['user_id']).to eq(nil)
          expect(json_response['invite_email']).to eq(email)
          expect(json_response['invite_token']).not_to eq(nil)
          expect(json_response['access_level']).to eq(Member::DEVELOPER)
        end
      end

      context 'access levels' do
        it 'does not create the member if group level is higher' do
          parent = create(:group)

          group.update!(parent: parent)
          project.update!(group: group)
          parent.add_developer(stranger)

          post api("/#{source_type.pluralize}/#{source.id}/invitations", maintainer),
               params: { email: stranger.email, access_level: Member::REPORTER }

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']['access_level']).to eq(["should be greater than or equal to Developer inherited membership from group #{parent.name}"])
        end

        it 'creates the member if group level is lower' do
          parent = create(:group)

          group.update!(parent: parent)
          project.update!(group: group)
          parent.add_developer(stranger)

          post api("/#{source_type.pluralize}/#{source.id}/invitations", maintainer),
               params: { email: stranger.email, access_level: Member::MAINTAINER }

          expect(response).to have_gitlab_http_status(:created)
          expect(json_response['invite_email']).to eq(stranger.email)
          expect(json_response['access_level']).to eq(Member::MAINTAINER)
        end
      end

      context 'access expiry date' do
        subject do
          post api("/#{source_type.pluralize}/#{source.id}/invitations", maintainer),
               params: { email: email, access_level: Member::DEVELOPER, expires_at: expires_at }
        end

        context 'when set to a date in the past' do
          let(:expires_at) { 2.days.ago.to_date }

          it 'does not create a member' do
            expect do
              subject
            end.not_to change { source.members.count }

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to eq({ 'expires_at' => ['cannot be a date in the past'] })
          end
        end

        context 'when set to a date in the future' do
          let(:expires_at) { 2.days.from_now.to_date }

          it 'invites a member' do
            expect do
              subject
            end.to change { source.requesters.count }.by(1)

            expect(response).to have_gitlab_http_status(:created)
            expect(json_response['user_id']).to eq(nil)
            expect(json_response['expires_at']).to eq(expires_at.to_s)
          end
        end
      end

      it "returns 409 if member already exists" do
        post api("/#{source_type.pluralize}/#{source.id}/invitations", maintainer),
             params: { email: maintainer.email, access_level: Member::MAINTAINER }

        expect(response).to have_gitlab_http_status(:conflict)
      end

      it 'returns 404 when the email is not valid' do
        post api("/#{source_type.pluralize}/#{source.id}/invitations", maintainer),
             params: { email: '', access_level: Member::MAINTAINER }

        expect(response).to have_gitlab_http_status(:not_found)
        expect(json_response['message']).to eq('404 User Not Found')
      end

      it 'returns 400 when email is not given' do
        post api("/#{source_type.pluralize}/#{source.id}/invitations", maintainer),
             params: { access_level: Member::MAINTAINER }

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'returns 400 when access_level is not given' do
        post api("/#{source_type.pluralize}/#{source.id}/invitations", maintainer),
             params: { email: email }

        expect(response).to have_gitlab_http_status(:bad_request)
      end

      it 'returns 400 when access_level is not valid' do
        post invitations_url(source, maintainer),
             params: { email: email, access_level: non_existing_record_access_level }

        expect(response).to have_gitlab_http_status(:bad_request)
      end
    end
  end

  describe 'POST /projects/:id/invitations' do
    it_behaves_like 'POST /:source_type/:id/invitations', 'project' do
      let(:source) { project }
    end
  end

  describe 'POST /groups/:id/invitations' do
    it_behaves_like 'POST /:source_type/:id/invitations', 'group' do
      let(:source) { group }
    end
  end
end
