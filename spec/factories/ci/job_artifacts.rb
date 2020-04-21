# frozen_string_literal: true

include ActionDispatch::TestProcess

FactoryBot.define do
  factory :ci_job_artifact, class: 'Ci::JobArtifact' do
    job factory: :ci_build
    file_type { :archive }
    file_format { :zip }

    trait :expired do
      expire_at { Date.yesterday }
    end

    trait :remote_store do
      file_store { JobArtifactUploader::Store::REMOTE}
    end

    after :build do |artifact|
      artifact.project ||= artifact.job.project
    end

    trait :raw do
      file_format { :raw }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('spec/fixtures/trace/sample_trace'), 'text/plain')
      end
    end

    trait :zip do
      file_format { :zip }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('spec/fixtures/ci_build_artifacts.zip'), 'application/zip')
      end
    end

    trait :gzip do
      file_format { :gzip }

      after(:build) do |artifact, _|
        artifact.file = fixture_file_upload(
          Rails.root.join('spec/fixtures/ci_build_artifacts_metadata.gz'), 'application/x-gzip')
      end
    end

    trait :archive do
      file_type { :archive }
      file_format { :zip }

      transient do
        file { fixture_file_upload(Rails.root.join('spec/fixtures/ci_build_artifacts.zip'), 'application/zip') }
      end

      after(:build) do |artifact, evaluator|
        artifact.file = evaluator.file
      end
    end

    trait :legacy_archive do
      archive

      file_location { :legacy_path }
    end

    trait :metadata do
      file_type { :metadata }
      file_format { :gzip }

      transient do
        file { fixture_file_upload(Rails.root.join('spec/fixtures/ci_build_artifacts_metadata.gz'), 'application/x-gzip') }
      end

      after(:build) do |artifact, evaluator|
        artifact.file = evaluator.file
      end
    end

    trait :trace do
      file_type { :trace }
      file_format { :raw }

      after(:build) do |artifact, evaluator|
        artifact.file = fixture_file_upload(
          Rails.root.join('spec/fixtures/trace/sample_trace'), 'text/plain')
      end
    end

    trait :junit do
      file_type { :junit }
      file_format { :gzip }

      after(:build) do |artifact, evaluator|
        artifact.file = fixture_file_upload(
          Rails.root.join('spec/fixtures/junit/junit.xml.gz'), 'application/x-gzip')
      end
    end

    trait :junit_with_attachment do
      file_type { :junit }
      file_format { :gzip }

      after(:build) do |artifact, evaluator|
        artifact.file = fixture_file_upload(
          Rails.root.join('spec/fixtures/junit/junit_with_attachment.xml.gz'), 'application/x-gzip')
      end
    end

    trait :junit_with_ant do
      file_type { :junit }
      file_format { :gzip }

      after(:build) do |artifact, evaluator|
        artifact.file = fixture_file_upload(
          Rails.root.join('spec/fixtures/junit/junit_ant.xml.gz'), 'application/x-gzip')
      end
    end

    trait :junit_with_three_testsuites do
      file_type { :junit }
      file_format { :gzip }

      after(:build) do |artifact, evaluator|
        artifact.file = fixture_file_upload(
          Rails.root.join('spec/fixtures/junit/junit_with_three_testsuites.xml.gz'), 'application/x-gzip')
      end
    end

    trait :junit_with_corrupted_data do
      file_type { :junit }
      file_format { :gzip }

      after(:build) do |artifact, evaluator|
        artifact.file = fixture_file_upload(
          Rails.root.join('spec/fixtures/junit/junit_with_corrupted_data.xml.gz'), 'application/x-gzip')
      end
    end

    trait :cobertura do
      file_type { :cobertura }
      file_format { :gzip }

      after(:build) do |artifact, evaluator|
        artifact.file = fixture_file_upload(
          Rails.root.join('spec/fixtures/cobertura/coverage.xml.gz'), 'application/x-gzip')
      end
    end

    trait :terraform do
      file_type { :terraform }
      file_format { :raw }

      after(:build) do |artifact, evaluator|
        artifact.file = fixture_file_upload(
          Rails.root.join('spec/fixtures/terraform/tfplan.json'), 'application/json')
      end
    end

    trait :terraform_with_corrupted_data do
      file_type { :terraform }
      file_format { :raw }

      after(:build) do |artifact, evaluator|
        artifact.file = fixture_file_upload(
          Rails.root.join('spec/fixtures/terraform/tfplan_with_corrupted_data.json'), 'application/json')
      end
    end

    trait :coverage_gocov_xml do
      file_type { :cobertura }
      file_format { :gzip }

      after(:build) do |artifact, evaluator|
        artifact.file = fixture_file_upload(
          Rails.root.join('spec/fixtures/cobertura/coverage_gocov_xml.xml.gz'), 'application/x-gzip')
      end
    end

    trait :coverage_with_corrupted_data do
      file_type { :cobertura }
      file_format { :gzip }

      after(:build) do |artifact, evaluator|
        artifact.file = fixture_file_upload(
          Rails.root.join('spec/fixtures/cobertura/coverage_with_corrupted_data.xml.gz'), 'application/x-gzip')
      end
    end

    trait :codequality do
      file_type { :codequality }
      file_format { :raw }

      after(:build) do |artifact, evaluator|
        artifact.file = fixture_file_upload(
          Rails.root.join('spec/fixtures/codequality/codequality.json'), 'application/json')
      end
    end

    trait :lsif do
      file_type { :lsif }
      file_format { :gzip }

      after(:build) do |artifact, evaluator|
        artifact.file = fixture_file_upload(
          Rails.root.join('spec/fixtures/lsif.json.gz'), 'application/x-gzip')
      end
    end

    trait :dotenv do
      file_type { :dotenv }
      file_format { :gzip }

      after(:build) do |artifact, evaluator|
        artifact.file = fixture_file_upload(
          Rails.root.join('spec/fixtures/build.env.gz'), 'application/x-gzip')
      end
    end

    trait :correct_checksum do
      after(:build) do |artifact, evaluator|
        artifact.file_sha256 = Digest::SHA256.file(artifact.file.path).hexdigest
      end
    end
  end
end
