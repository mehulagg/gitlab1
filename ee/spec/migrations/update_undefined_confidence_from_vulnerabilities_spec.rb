# frozen_string_literal: true

require 'spec_helper'

require Rails.root.join('db', 'post_migrate', '20200511092714_update_undefined_confidence_from_vulnerabilities.rb')

RSpec.describe UpdateUndefinedConfidenceFromVulnerabilities, :migration do
  let(:vulnerabilities) { table(:vulnerabilities) }
  let(:identifiers) { table(:vulnerability_identifiers) }
  let(:projects) { table(:projects) }
  let(:namespaces) { table(:namespaces) }
  let(:users) { table(:users) }

  before do
    namespace = namespaces.create!(name: 'namespace1', path: 'namespace1')
    projects.create!(id: 123, namespace_id: namespace.id, name: 'gitlab', path: 'gitlab')
    users.create!(id: 13, email: 'author@example.com', notification_email: 'author@example.com', name: 'author', username: 'author', projects_limit: 10, state: 'active')
    stub_const("#{described_class}::BATCH_SIZE", 2)
  end

  it 'updates undefined confidence levels to unkown', :sidekiq_might_not_need_inline do
    allow_any_instance_of(Gitlab).to receive(:ee?).and_return(true)

    vulnerabilities.create!(vuln_params)
    vulnerabilities.create!(vuln_params.merge(confidence: 2))

    expect(vulnerabilities.where(confidence: 0).count). to eq(1)

    migrate!

    expect(vulnerabilities.exists?(confidence: 0)).to be_falsy
    expect(vulnerabilities.where(confidence: 2).count).to eq(2)
  end

  it 'skips migration for ce' do
    allow_any_instance_of(Gitlab).to receive(:ee?).and_return(false)

    vulnerabilities.create!(vuln_params)

    expect(vulnerabilities.where(confidence: 0).count). to eq(1)

    migrate!

    expect(vulnerabilities.exists?(confidence: 0)).to be_truthy
  end

  def vuln_params
    {
      title: 'title',
      state: 1,
      confidence: 0,
      severity: 5,
      report_type: 2,
      project_id: 123,
      author_id: 13
    }
  end
end
