# frozen_string_literal: true

require 'spec_helper'
require Rails.root.join('db', 'post_migrate', '20210423160427_schedule_drop_invalid_vulnerabilities.rb')

RSpec.describe ScheduleDropInvalidVulnerabilities, :migration do
  let(:namespace) { table(:namespaces).create!(name: 'user', path: 'user') }
  let(:users) { table(:users) }
  let(:user) { create_user! }
  let(:project) { table(:projects).create!(id: 123, namespace_id: namespace.id) }

  let(:scanners) { table(:vulnerability_scanners) }
  let(:scanner) { scanners.create!(project_id: project.id, external_id: 'test 1', name: 'test scanner 1') }
  let(:different_scanner) { scanners.create!(project_id: project.id, external_id: 'test 2', name: 'test scanner 2') }

  let(:vulnerability_identifiers) { table(:vulnerability_identifiers) }
  let(:primary_identifier) do
    vulnerability_identifiers.create!(
      project_id: project.id,
      external_type: 'uuid-v5',
      external_id: 'uuid-v5',
      fingerprint: '7e394d1b1eb461a7406d7b1e08f057a1cf11287a',
      name: 'Identifier for UUIDv5')
  end

  let(:vulnerabilities_findings) { table(:vulnerability_occurrences) }
  let!(:finding) do
    create_finding!(
      vulnerability_id: vulnerability_with_finding.id,
      project_id: project.id,
      scanner_id: scanner.id,
      primary_identifier_id: primary_identifier.id
    )
  end

  let(:vulnerabilities) { table(:vulnerabilities) }
  let!(:vulnerability_with_finding) do
    create_vulnerability!(
      project_id: project.id,
      author_id: user.id
    )
  end

  let!(:vulnerability_without_finding) do
    create_vulnerability!(
      project_id: project.id,
      author_id: user.id
    )
  end

  before do
    stub_const("#{described_class}::BATCH_SIZE", 1)
  end

  around do |example|
    freeze_time { Sidekiq::Testing.fake! { example.run } }
  end

  it 'schedules background migrations' do
    migrate!

    expect(BackgroundMigrationWorker.jobs.size).to eq(2)
    expect(described_class::MIGRATION).to be_scheduled_migration(vulnerability_with_finding.id, vulnerability_with_finding.id)
    expect(described_class::MIGRATION).to be_scheduled_migration(vulnerability_without_finding.id, vulnerability_without_finding.id)
  end

  private

  def create_vulnerability!(project_id:, author_id:, title: 'test', severity: 7, confidence: 7, report_type: 0)
    vulnerabilities.create!(
      project_id: project_id,
      author_id: author_id,
      title: title,
      severity: severity,
      confidence: confidence,
      report_type: report_type
    )
  end

  # rubocop:disable Metrics/ParameterLists
  def create_finding!(
    vulnerability_id:, project_id:, scanner_id:, primary_identifier_id:,
                      name: "test", severity: 7, confidence: 7, report_type: 0,
                      project_fingerprint: '123qweasdzxc', location_fingerprint: 'test',
                      metadata_version: 'test', raw_metadata: 'test', uuid: 'test')
    vulnerabilities_findings.create!(
      vulnerability_id: vulnerability_id,
      project_id: project_id,
      name: name,
      severity: severity,
      confidence: confidence,
      report_type: report_type,
      project_fingerprint: project_fingerprint,
      scanner_id: scanner_id,
      primary_identifier_id: primary_identifier_id,
      location_fingerprint: location_fingerprint,
      metadata_version: metadata_version,
      raw_metadata: raw_metadata,
      uuid: uuid
    )
  end
  # rubocop:enable Metrics/ParameterLists

  def create_user!(name: "Example User", email: "user@example.com", user_type: nil, created_at: Time.zone.now, confirmed_at: Time.zone.now)
    users.create!(
      name: name,
      email: email,
      username: name,
      projects_limit: 0,
      user_type: user_type,
      confirmed_at: confirmed_at
    )
  end
end
