# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Framework do
  let_it_be(:framework) { create(:compliance_framework) }

  subject { framework }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_length_of(:name).is_at_most(255) }
  it { is_expected.to validate_length_of(:description).is_at_most(255) }
  it { is_expected.to validate_length_of(:color).is_at_most(7) }

  describe 'color' do
    context 'with whitespace' do
      let_it_be(:framework) { create(:compliance_framework, color: ' #ABC123 ')}

      it 'strips whitespace' do
        expect(subject.color).to eq('#ABC123')
      end
    end
  end

  describe 'display_name' do
    it 'concatenates the name and description' do
      expect(subject.display_name).to eq("#{subject.name} - #{subject.description}")
    end
  end
end
