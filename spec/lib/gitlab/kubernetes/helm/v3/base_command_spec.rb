# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Kubernetes::Helm::V3::BaseCommand do
  subject(:base_command) do
    test_class.new(rbac)
  end

  let(:application) { create(:clusters_applications_helm) }
  let(:rbac) { false }

  let(:test_class) do
    Class.new(described_class) do
      def initialize(rbac)
        super(
          name: 'test-class-name',
          rbac: rbac,
          files: { some: 'value' }
        )
      end
    end
  end

  describe '#helm_version' do
    subject { base_command.helm_version }

    it { is_expected.to match /^3\.\d+\.\d+$/ }
  end

  it_behaves_like 'helm command generator' do
    let(:commands) { '' }
  end

  describe '#pod_name' do
    subject { base_command.pod_name }

    it { is_expected.to eq('install-test-class-name') }
  end

  it_behaves_like 'helm command' do
    let(:command) { base_command }
  end
end
