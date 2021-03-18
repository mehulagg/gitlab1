# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::ContentSecurityPolicy::ConfigLoader do
  let(:policy) { ActionDispatch::ContentSecurityPolicy.new }
  let(:csp_config) do
    {
      enabled: true,
      report_only: false,
      directives: {
        base_uri: 'http://example.com',
        child_src: "'self' https://child.example.com",
        default_src: "'self' https://other.example.com",
        script_src: "'self'  https://script.exammple.com ",
        worker_src: "data:  https://worker.example.com",
        report_uri: "http://example.com"
      }
    }
  end

  describe '.default_settings_hash' do
    it 'returns empty defaults' do
      settings = described_class.default_settings_hash

      expect(settings['enabled']).to be_truthy
      expect(settings['report_only']).to be_falsey

      directives = settings['directives']
      directive_names = (described_class::DIRECTIVES - ['report_uri'])
      directive_names.each do |directive|
        expect(directives.has_key?(directive)).to be_truthy
        expect(directives[directive]).to be_truthy
      end

      expect(directives.has_key?('report_uri')).to be_truthy
      expect(directives['report_uri']).to be_nil
    end
  end

  describe '#load' do
    subject { described_class.new(csp_config[:directives]) }

    def expected_config(directive)
      csp_config[:directives][directive].split(' ').map(&:strip)
    end

    it 'sets the policy properly' do
      subject.load(policy)

      expect(policy.directives['base-uri']).to eq([csp_config[:directives][:base_uri]])
      expect(policy.directives['default-src']).to eq(expected_config(:default_src))
      expect(policy.directives['child-src']).to eq(expected_config(:child_src))
      expect(policy.directives['worker-src']).to eq(expected_config(:worker_src))
      expect(policy.directives['report-uri']).to eq(expected_config(:report_uri))
    end

    it 'ignores malformed policy statements' do
      csp_config[:directives][:base_uri] = 123

      subject.load(policy)

      expect(policy.directives['base-uri']).to be_nil
    end
  end
end
