# frozen_string_literal: true

class Iteration < ApplicationRecord
  self.table_name = 'sprints'

  attr_accessor :skip_future_date_validation
  attr_accessor :skip_project_validation

  STATE_ENUM_MAP = {
      upcoming: 1,
      started: 2,
      closed: 3
  }.with_indifferent_access.freeze

  include AtomicInternalId

  belongs_to :project
  belongs_to :group
  belongs_to :iteration_cadence

  has_internal_id :iid, scope: :project
  has_internal_id :iid, scope: :group

  validates :start_date, presence: true
  validates :due_date, presence: true

  validate :dates_do_not_overlap, if: :start_or_due_dates_changed?
  validate :future_date, if: :start_or_due_dates_changed?, unless: :skip_future_date_validation
  validate :no_project, unless: :skip_project_validation

  before_create :set_iteration_cadence

  scope :upcoming, -> { with_state(:upcoming) }
  scope :started, -> { with_state(:started) }
  scope :closed, -> { with_state(:closed) }

  scope :within_timeframe, -> (start_date, end_date) do
    where('start_date IS NOT NULL OR due_date IS NOT NULL')
      .where('start_date IS NULL OR start_date <= ?', end_date)
      .where('due_date IS NULL OR due_date >= ?', start_date)
  end

  scope :start_date_passed, -> { where('start_date <= ?', Date.current).where('due_date >= ?', Date.current) }
  scope :due_date_passed, -> { where('due_date < ?', Date.current) }

  state_machine :state_enum, initial: :upcoming do
    event :start do
      transition upcoming: :started
    end

    event :close do
      transition [:upcoming, :started] => :closed
    end

    state :upcoming, value: Iteration::STATE_ENUM_MAP[:upcoming]
    state :started, value: Iteration::STATE_ENUM_MAP[:started]
    state :closed, value: Iteration::STATE_ENUM_MAP[:closed]
  end

  # Alias to state machine .with_state_enum method
  # This needs to be defined after the state machine block to avoid errors
  class << self
    alias_method :with_state, :with_state_enum
    alias_method :with_states, :with_state_enums

    def filter_by_state(iterations, state)
      case state
      when 'closed' then iterations.closed
      when 'started' then iterations.started
      when 'upcoming' then iterations.upcoming
      when 'opened' then iterations.started.or(iterations.upcoming)
      when 'all' then iterations
      else raise ArgumentError, "Unknown state filter: #{state}"
      end
    end

    def reference_prefix
      '*iteration:'
    end

    def reference_pattern
      nil
    end
  end

  def state
    STATE_ENUM_MAP.key(state_enum)
  end

  def state=(value)
    self.state_enum = STATE_ENUM_MAP[value]
  end

  def resource_parent
    group || project
  end

  private

  def parent_group
    group || project.group
  end

  def start_or_due_dates_changed?
    start_date_changed? || due_date_changed?
  end

  # ensure dates do not overlap with other Iterations in the same cadence tree
  def dates_do_not_overlap
    return unless iteration_cadence.iterations.where.not(id: self.id).within_timeframe(start_date, due_date).exists?

    # for now we only have a single default cadence within a group just to wrap the iterations into a set.
    # once we introduce multiple cadences per group we need to change this message.
    # related issue: https://gitlab.com/gitlab-org/gitlab/-/issues/299312
    errors.add(:base, s_("Iteration|Dates cannot overlap with other existing Iterations within this group"))
  end

  # ensure dates are in the future
  def future_date
    if start_or_due_dates_changed?
      errors.add(:start_date, s_("Iteration|cannot be more than 500 years in the future")) if start_date > 500.years.from_now
      errors.add(:due_date, s_("Iteration|cannot be more than 500 years in the future")) if due_date > 500.years.from_now
    end
  end

  def no_project
    return unless project_id.present?

    errors.add(:project_id, s_("is not allowed. We do not currently support project-level iterations"))
  end

  # TODO: this method should be removed as part of https://gitlab.com/gitlab-org/gitlab/-/issues/296099
  def set_iteration_cadence
    return if iteration_cadence
    return unless group

    self.iteration_cadence = group.iteration_cadences.first || create_default_cadence
  end

  def create_default_cadence
    cadence_title = IterationCadence.default_title

    IterationCadence.create!(group: group, title: cadence_title, start_date: start_date, last_run_date: start_date)
  end

  # TODO: remove this as part of https://gitlab.com/gitlab-org/gitlab/-/issues/296100
  def validate_group
    return if iteration_cadence&.group == group
    return if project && !iteration_cadence

    errors.add(:group, s_('is not valid. The iteration group has to match the iteration cadence group.'))
  end
end

Iteration.prepend_if_ee('EE::Iteration')
