# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ci::TriggerEntity do
  let(:project) { create(:project) }
  let(:trigger) { create(:ci_trigger, project: project, token: '237f3604900a4cd71ed06ef13e57b96d') }
  let(:user) { create(:user) }
  let(:entity) { described_class.new(trigger, current_user: user, project: project) }

  describe '#as_json' do
    subject { entity.as_json }

    it 'contains required fields' do
      expect(subject).to include(
        :description, :owner, :last_used, :token, :has_token_exposed, :can_access_project
      )
    end

    it 'contains user fields' do
      expect(subject[:owner].to_json).to match_schema('entities/user')
    end

    context 'when current user can manage triggers' do
      before do
        project.add_maintainer(user)
      end

      it 'returns short_token as token' do
        expect(subject[:token]).to eq(trigger.short_token)
      end

      it 'contains project_trigger_path' do
        expect(subject[:project_trigger_path]).to eq("/#{project.full_path}/-/triggers/#{trigger.id}")
      end

      it 'does not contain edit_project_trigger_path' do
        expect(subject).not_to include(:edit_project_trigger_path)
      end

      it 'returns has_token_exposed' do
        expect(subject[:has_token_exposed]).to eq(false)
      end
    end

    context 'when current user is the owner of the trigger' do
      before do
        project.add_maintainer(user)
        trigger.update!(owner: user)
      end

      it 'returns token as token' do
        expect(subject[:token]).to eq(trigger.token)
      end

      it 'contains project_trigger_path' do
        expect(subject[:project_trigger_path]).to eq("/#{project.full_path}/-/triggers/#{trigger.id}")
      end

      it 'contains edit_project_trigger_path' do
        expect(subject[:edit_project_trigger_path]).to eq("/#{project.full_path}/-/triggers/#{trigger.id}/edit")
      end

      it 'returns has_token_exposed' do
        expect(subject[:has_token_exposed]).to eq(true)
      end
    end
  end
end
