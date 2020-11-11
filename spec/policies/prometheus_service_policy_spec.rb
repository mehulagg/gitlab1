# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PrometheusService, :models do
  let(:integration) { create(:prometheus_service) }
  let(:project) { integration.project }
  let(:user) { create(:user) }

  subject(:policy) { Ability.policy_for(user, integration) }

  describe 'rules' do
    it { is_expected.to be_disallowed :admin_project }

    context 'when maintainer' do
      before do
        project.add_maintainer(user)
      end

      it { is_expected.to be_allowed :admin_project }
    end
  end
end
