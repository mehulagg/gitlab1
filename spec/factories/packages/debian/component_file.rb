# frozen_string_literal: true

FactoryBot.define do
  factory :debian_project_component_file, class: 'Packages::Debian::ProjectComponentFile' do
    component { association(:debian_project_component) }
    architecture { association(:debian_project_architecture, distribution: component.distribution) }

    factory :debian_group_component_file, class: 'Packages::Debian::GroupComponentFile' do
      component { association(:debian_group_component) }
      architecture { association(:debian_group_architecture, distribution: component.distribution) }
    end

    file_type { :packages }

    after(:build) do |component_file, evaluator|
      component_file.file = Rack::Test::UploadedFile.new('spec/fixtures/packages/debian/distribution/Packages')
    end

    file_md5 { '12345abcde' }
    file_sha256 { 'be93151dc23ac34a82752444556fe79b32c7a1ad' }

    trait(:packages) do
      file_type { :packages }
    end

    trait(:source) do
      file_type { :source }
      architecture { nil }
    end

    trait(:di_packages) do
      file_type { :di_packages }
    end

    trait(:object_storage) do
      file_store { Packages::PackageFileUploader::Store::REMOTE }
    end
  end
end
