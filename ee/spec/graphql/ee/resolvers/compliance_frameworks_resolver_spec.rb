# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::ComplianceFrameworksResolver do
  include GraphqlHelpers

  let(:project) { create(:project) }

  let_it_be(:compliance_framework) { create(:compliance_framework) }

  describe '#resolve' do
    subject { resolve_compliance_frameworks(project) }

    context 'when a project has a compliance framework set' do
      before do
        project.update!(compliance_framework_setting: create(:compliance_framework_project_setting, framework: compliance_framework))
      end

      it 'includes the name of the compliance frameworks' do
        expect(subject).to contain_exactly(compliance_framework)
      end
    end

    context 'when a project has no compliance framework set' do
      it 'is an empty array' do
        expect(subject).to be_empty
      end
    end
  end

  def resolve_compliance_frameworks(project)
    resolve(described_class, obj: project)
  end
end
