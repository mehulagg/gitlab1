# frozen_string_literal: true

FactoryBot.define do
  factory :ci_reports_security_finding, class: '::Gitlab::Ci::Reports::Security::Finding' do
    confidence { :medium }
    identifiers { Array.new(1) { association(:ci_reports_security_identifier) } }
    location factory: :ci_reports_security_locations_sast
    metadata_version { 'sast:1.0' }
    name { 'Cipher with no integrity' }
    report_type { :sast }
    raw_metadata do
      {
        description: "The cipher does not provide data integrity update 1",
        solution: "GCM mode introduces an HMAC into the resulting encrypted data, providing integrity of the result.",
        location: {
          file: "maven/src/main/java/com/gitlab/security_products/tests/App.java",
          start_line: 29,
          end_line: 29,
          class: "com.gitlab.security_products.tests.App",
          method: "insecureCypher"
        },
        links: [
          {
            name: "Cipher does not check for integrity first?",
            url: "https://crypto.stackexchange.com/questions/31428/pbewithmd5anddes-cipher-does-not-check-for-integrity-first"
          }
        ]
      }.to_json
    end
    trackings { [] }
    scanner factory: :ci_reports_security_scanner
    severity { :high }
    scan factory: :ci_reports_security_scan
    sequence(:uuid) { generate(:vulnerability_finding_uuid) }

    skip_create

    trait :dynamic do
      location { association(:ci_reports_security_locations_sast, :dynamic) }
    end

    initialize_with do
      ::Gitlab::Ci::Reports::Security::Finding.new(**attributes)
    end
  end
end
