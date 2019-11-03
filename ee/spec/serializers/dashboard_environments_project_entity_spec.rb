# frozen_string_literal: true

require 'spec_helper'

describe DashboardEnvironmentsProjectEntity do
  describe '.as_json' do
    it 'includes project attributes' do
      current_user = create(:user)
      project = create(:project)
      environment = create(:environment)
      entity_request = EntityRequest.new(current_user: current_user)

      result = described_class.new(project, { environments: [environment], request: entity_request }).as_json

      expect(result.keys.sort).to eq([:avatar_url, :environments, :id, :name, :namespace, :remove_path, :web_url])
    end
  end
end
