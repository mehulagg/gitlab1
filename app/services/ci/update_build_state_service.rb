# frozen_string_literal: true

module Ci
  class UpdateBuildStateService
    include ::Gitlab::Utils::StrongMemoize
    include ::Gitlab::ExclusiveLeaseHelpers

    Result = Struct.new(:status, :backoff, keyword_init: true)

    ACCEPT_TIMEOUT = 5.minutes.freeze

    attr_reader :build, :params, :metrics

    def initialize(build, params, metrics = ::Gitlab::Ci::Trace::Metrics.new)
      @build = build
      @params = params
      @metrics = metrics
    end

    def execute
      overwrite_trace! if has_trace?

      unless accept_available?
        return update_build_state!
      end

      ensure_pending_state!

      in_build_trace_lock do
        process_build_state!
      end
    end

    private

    def overwrite_trace!
      metrics.increment_trace_operation(operation: :overwrite)

      build.trace.set(params[:trace]) if Gitlab::Ci::Features.trace_overwrite?
    end

    def ensure_pending_state!
      pending_state.created_at
    end

    def process_build_state!
      if live_chunks_pending?
        if pending_state_outdated?
          discard_build_trace!
          update_build_state!
        else
          accept_build_state!
        end
      else
        validate_build_trace!
        update_build_state!
      end
    end

    def accept_build_state!
      build.trace_chunks.live.find_each do |chunk|
        chunk.schedule_to_persist!
      end

      metrics.increment_trace_operation(operation: :accepted)

      ::Gitlab::Ci::Runner::Backoff.new(pending_state.created_at).then do |backoff|
        Result.new(status: 202, backoff: backoff.to_seconds)
      end
    end

    def validate_build_trace!
      if chunks_persisted?
        metrics.increment_trace_operation(operation: :finalized)
      end

      unless ::Gitlab::Ci::Trace::Checksum.new(build).valid?
        metrics.increment_trace_operation(operation: :invalid)
      end
    end

    def update_build_state!
      case build_state
      when 'running'
        build.touch if build.needs_touch?

        Result.new(status: 200)
      when 'success'
        build.success!

        Result.new(status: 200)
      when 'failed'
        build.drop!(params[:failure_reason] || :unknown_failure)

        Result.new(status: 200)
      else
        Result.new(status: 400)
      end
    end

    def discard_build_trace!
      metrics.increment_trace_operation(operation: :discarded)
    end

    def accept_available?
      !build_running? && has_checksum? && chunks_migration_enabled?
    end

    def live_chunks_pending?
      build.trace_chunks.live.any?
    end

    def chunks_persisted?
      build.trace_chunks.any? && !live_chunks_pending?
    end

    def pending_state_outdated?
      Time.current - pending_state.created_at > ACCEPT_TIMEOUT
    end

    def build_state
      params.dig(:state).to_s
    end

    def has_trace?
      params.dig(:trace).present?
    end

    def has_checksum?
      params.dig(:checksum).present?
    end

    def build_running?
      build_state == 'running'
    end

    def pending_state
      strong_memoize(:pending_state) { ensure_pending_state }
    end

    def ensure_pending_state
      Ci::BuildPendingState.create_or_find_by!(
        build_id: build.id,
        state: params.fetch(:state),
        trace_checksum: params.fetch(:checksum),
        failure_reason: params.dig(:failure_reason)
      )
    rescue ActiveRecord::RecordNotFound
      metrics.increment_trace_operation(operation: :conflict)

      build.pending_state
    end

    ##
    # This method is releasing an exclusive lock on a build trace the moment we
    # conclude that build status has been written and the build state update
    # has been committed to the database.
    #
    # Because a build state machine schedules a bunch of workers to run after
    # build status transition to complete, we do not want to keep the lease
    # until all the workers are scheduled because it opens a possibility of
    # race conditions happening.
    #
    # Instead of keeping the lease until the transition is fully done and
    # workers are scheduled, we immediately release the lock after the database
    # commit happens.
    #
    def in_build_trace_lock(&block)
      build.trace.lock do |_, lease| # rubocop:disable CodeReuse/ActiveRecord
        build.run_on_status_commit { lease.cancel }

        yield
      end
    rescue ::Gitlab::Ci::Trace::LockedError
      metrics.increment_trace_operation(operation: :locked)

      accept_build_state!
    end

    def chunks_migration_enabled?
      ::Gitlab::Ci::Features.accept_trace?(build.project)
    end
  end
end
