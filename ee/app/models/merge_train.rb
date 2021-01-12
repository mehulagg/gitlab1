# frozen_string_literal: true

class MergeTrain < ApplicationRecord
  include AfterCommitQueue

  ACTIVE_STATUSES = %w[idle stale fresh].freeze
  COMPLETE_STATUSES = %w[merged merging].freeze

  belongs_to :target_project, class_name: "Project"
  belongs_to :merge_request, inverse_of: :merge_train
  belongs_to :user
  belongs_to :pipeline, class_name: 'Ci::Pipeline'

  after_destroy do |merge_train|
    run_after_commit do
      merge_train.pipeline&.cancel_running(retries: 1)
      merge_train.cleanup_ref
    end
  end

  state_machine :status, initial: :idle do
    event :refresh_pipeline do
      transition %i[idle stale fresh] => :fresh
    end

    event :outdate_pipeline do
      transition fresh: :stale
    end

    event :start_merge do
      transition fresh: :merging
    end

    event :finish_merge do
      transition merging: :merged
    end

    before_transition on: :refresh_pipeline do |merge_train, transition|
      pipeline_id = transition.args.first
      merge_train.pipeline_id = pipeline_id
    end

    before_transition any => :merged do |merge_train|
      merged_at = Time.zone.now
      merge_train.merged_at = merged_at
      merge_train.duration = merged_at - merge_train.created_at
    end

    after_transition fresh: :stale do |merge_train|
      merge_train.run_after_commit do
        merge_train.refresh_async
      end
    end

    after_transition merging: :merged do |merge_train|
      merge_train.run_after_commit do
        merge_train.cleanup_ref
      end
    end

    state :idle, value: 0
    state :merged, value: 1
    state :stale, value: 2
    state :fresh, value: 3
    state :merging, value: 4
  end

  scope :active, -> { with_status(*ACTIVE_STATUSES) }
  scope :complete, -> { with_status(*COMPLETE_STATUSES) }
  scope :for_target, -> (project_id, branch) { where(target_project_id: project_id, target_branch: branch) }
  scope :by_id, -> (sort = :asc) { order(id: sort) }

  scope :preload_api_entities, -> do
    preload(:user, :merge_request, pipeline: Ci::Pipeline::PROJECT_ROUTE_AND_NAMESPACE_ROUTE)
      .merge(MergeRequest.preload_routables)
  end

  class << self
    def all_active_mrs_in_train(target_project_id, target_branch)
      MergeRequest.joins(:merge_train).merge(
        MergeTrain.active.for_target(target_project_id, target_branch).by_id
      )
    end

    def first_mrs_in_trains(project)
      MergeRequest.preload(:target_project).where(id: first_merge_request_ids(project))
    end

    def sha_exists_in_history?(target_project_id, target_branch, newrev, limit: 20)
      MergeRequest.where(id: complete_merge_trains(target_project_id, target_branch, limit: limit))
                  .where('merge_commit_sha = ? OR in_progress_merge_commit_sha = ?', newrev, newrev)
                  .exists?
    end

    def total_count_in_train(merge_request)
      all_active_mrs_in_train(merge_request.target_project_id, merge_request.target_branch).count
    end

    private

    def first_merge_request_ids(project)
      MergeTrain.where(target_project: project)
        .active
        .select('DISTINCT ON (target_branch) merge_request_id')
        .order(:target_branch, :id)
    end

    def complete_merge_trains(target_project_id, target_branch, limit:)
      MergeTrain.for_target(target_project_id, target_branch)
        .complete.order(id: :desc).select(:merge_request_id).limit(limit)
    end
  end

  def all(limit: nil)
    self.class.active.for_target(target_project_id, target_branch).by_id.limit(limit)
  end

  def all_next
    all.where('merge_trains.id > ?', id)
  end

  def all_prev
    all.where('merge_trains.id < ?', id)
  end

  def next
    all_next.first
  end

  def prev
    all_prev.last
  end

  def index
    all_prev.count
  end

  def first
    all.first
  end

  def first_in_train?
    self == first
  end

  def cleanup_ref
    merge_request.cleanup_refs(only: :train)
  end

  def active?
    ACTIVE_STATUSES.include?(status_name.to_s)
  end

  def refresh_async
    AutoMergeProcessWorker.perform_async(merge_request_id)
  end
end
