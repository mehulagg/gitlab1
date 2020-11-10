# frozen_string_literal: true

module Gitlab
  module Geo
    # This concern is included on ActiveRecord classes to manage their
    # verification fields. This concern does not handle how verification is
    # performed.
    #
    # This is a separate concern from Gitlab::Geo::ReplicableModel because e.g.
    # MergeRequestDiff stores its verification state in a separate table with
    # the association to MergeRequestDiffDetail.
    module VerificationState
      extend ActiveSupport::Concern
      include ::ShaAttribute
      include Delay

      VERIFICATION_STATE_VALUES = {
        verification_pending: 0,
        verification_started: 1,
        verification_succeeded: 2,
        verification_failed: 3
      }.freeze
      VERIFICATION_TIMEOUT = 8.hours

      included do
        sha_attribute :verification_checksum

        # rubocop:disable CodeReuse/ActiveRecord
        scope :verification_pending, -> { with_verification_state(:verification_pending) }
        scope :verification_started, -> { with_verification_state(:verification_started) }
        scope :verification_succeeded, -> { with_verification_state(:verification_succeeded) }
        scope :verification_failed, -> { with_verification_state(:verification_failed) }
        scope :checksummed, -> { where.not(verification_checksum: nil) }
        scope :not_checksummed, -> { where(verification_checksum: nil) }
        scope :never_attempted_verification, -> { verification_pending.where(verification_started_at: nil) }
        scope :needs_verification_again, -> { verification_pending.where.not(verification_started_at: nil).or(verification_failed) }
        scope :verification_timed_out, -> { verification_started.where("verification_started_at < ?", VERIFICATION_TIMEOUT.ago) }
        scope :needs_verification, -> { verification_pending.or(verification_failed) }
        # rubocop:enable CodeReuse/ActiveRecord

        state_machine :verification_state, initial: :verification_pending do
          state :verification_pending, value: VERIFICATION_STATE_VALUES[:verification_pending]
          state :verification_started, value: VERIFICATION_STATE_VALUES[:verification_started]
          state :verification_succeeded, value: VERIFICATION_STATE_VALUES[:verification_succeeded]
          state :verification_failed, value: VERIFICATION_STATE_VALUES[:verification_failed] do
            validates :verification_failure, presence: true
          end

          before_transition any => :verification_started do |instance, _|
            instance.verification_started_at = Time.current
            instance.verification_failure = nil
          end

          before_transition any => :verification_pending do |instance, _|
            instance.verification_retry_count = 0
            instance.verification_retry_at = nil
            instance.verification_failure = nil
          end

          before_transition any => :verification_failed do |instance, _|
            instance.verification_retry_count += 1
            instance.verification_retry_at = instance.next_retry_time(instance.verification_retry_count)
          end

          before_transition any => :verification_succeeded do |instance, _|
            instance.verification_retry_count = 0
            instance.verification_retry_at = nil
            instance.verification_failure = nil
          end

          event :verification_started do
            transition [:verification_pending, :verification_succeeded, :verification_failed] => :verification_started
          end

          event :verification_succeeded do
            transition verification_started: :verification_succeeded
          end

          event :verification_failed do
            transition verification_started: :verification_failed
          end

          event :verification_pending do
            transition [:verification_started, :verification_succeeded, :verification_failed] => :verification_pending
          end
        end
      end

      # @param [String] message error information
      # @param [StandardError] error exception
      def set_verification_failure(message, error = nil)
        self.verification_failure = message
        self.verification_failure += ": #{error.message}" if error.respond_to?(:message)
      end
    end
  end
end
