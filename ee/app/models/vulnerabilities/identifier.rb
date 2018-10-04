# frozen_string_literal: true

module Vulnerabilities
  class Identifier < ActiveRecord::Base
    include ShaAttribute

    self.table_name = "vulnerability_identifiers"

    sha_attribute :fingerprint

    has_many :occurrence_identifiers, class_name: 'Vulnerabilities::OccurrenceIdentifier'
    has_many :occurrences, through: :occurrence_identifiers, class_name: 'Vulnerabilities::Occurrence'

    has_many :occurrence_pipelines, class_name: 'Vulnerabilities::OccurrencePipeline'
    has_many :pipelines, through: :occurrence_pipelines, class_name: 'Ci::Pipeline'

    has_one :primary_identifier, class_name: 'Vulnerabilities::Identifier'

    belongs_to :project

    validates :project, presence: true
    validates :external_type, presence: true
    validates :external_id, presence: true
    validates :fingerprint, presence: true
    # Uniqueness validation doesn't work with binary columns, so save this useless query. It is enforce by DB constraint anyway.
    # TODO: find out why it fails
    # validates :fingerprint, presence: true, uniqueness: { scope: :project_id }
    validates :name, presence: true

    scope :with_fingerprint, -> (fingerprints) { where(fingerprint: fingerprints) }
  end
end
