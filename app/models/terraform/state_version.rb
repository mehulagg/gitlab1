# frozen_string_literal: true

module Terraform
  class StateVersion < ApplicationRecord
    include FileStoreMounter

    belongs_to :terraform_state, class_name: 'Terraform::State', optional: false
    belongs_to :created_by_user, class_name: 'User', optional: true
    belongs_to :build, class_name: 'Ci::Build', optional: true, foreign_key: :ci_build_id

    scope :ordered_by_version_desc, -> { order(version: :desc) }
    scope :with_files_stored_locally, -> { where(file_store: Terraform::StateUploader::Store::LOCAL) }
    scope :with_files_stored_remotely, -> { where(file_store: Terraform::StateUploader::Store::REMOTE) }

    default_value_for(:file_store) { StateUploader.default_store }

    mount_file_store_uploader StateUploader

    delegate :project_id, :uuid, to: :terraform_state, allow_nil: true

    def local?
      file_store == ObjectStorage::Store::LOCAL
    end
  end
end

Terraform::StateVersion.prepend_if_ee('EE::Terraform::StateVersion')
