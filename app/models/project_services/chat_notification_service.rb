# frozen_string_literal: true

# Base class for Chat notifications services
# This class is not meant to be used directly, but only to inherit from.
class ChatNotificationService < Service
  include ChatMessage
  include NotificationBranchSelection

  SUPPORTED_EVENTS = %w[
    push issue confidential_issue merge_request note confidential_note
    tag_push pipeline wiki_page deployment
  ].freeze

  SUPPORTED_EVENTS_FOR_LABEL_FILTER = %w[issue confidential_issue merge_request note confidential_note].freeze

  EVENT_CHANNEL = proc { |event| "#{event}_channel" }

  default_value_for :category, 'chat'

  prop_accessor :webhook, :username, :channel, :branches_to_be_notified, :labels_to_be_notified

  # Custom serialized properties initialization
  prop_accessor(*SUPPORTED_EVENTS.map { |event| EVENT_CHANNEL[event] })

  boolean_accessor :notify_only_broken_pipelines, :notify_only_default_branch

  validates :webhook, presence: true, public_url: true, if: :activated?

  def initialize_properties
    if properties.nil?
      self.properties = {}
      self.notify_only_broken_pipelines = true
      self.branches_to_be_notified = "default"
    elsif !self.notify_only_default_branch.nil?
      # In older versions, there was only a boolean property named
      # `notify_only_default_branch`. Now we have a string property named
      # `branches_to_be_notified`. Instead of doing a background migration, we
      # opted to set a value for the new property based on the old one, if
      # users hasn't specified one already. When users edit the service and
      # selects a value for this new property, it will override everything.

      self.branches_to_be_notified ||= notify_only_default_branch? ? "default" : "all"
    end
  end

  def confidential_issue_channel
    properties['confidential_issue_channel'].presence || properties['issue_channel']
  end

  def confidential_note_channel
    properties['confidential_note_channel'].presence || properties['note_channel']
  end

  def self.supported_events
    SUPPORTED_EVENTS
  end

  def fields
    default_fields + build_event_channels
  end

  def default_fields
    [
      { type: 'text', name: 'webhook', placeholder: "#{webhook_placeholder}", required: true }.freeze,
      { type: 'text', name: 'username', placeholder: 'username' }.freeze,
      { type: 'checkbox', name: 'notify_only_broken_pipelines' }.freeze,
      { type: 'select', name: 'branches_to_be_notified', choices: branch_choices }.freeze,
      { type: 'text', name: 'labels_to_be_notified', placeholder: '~backend,~frontend', help: 'For issue, merge request, and note events only.' }.freeze
    ].freeze
  end

  def execute(data)
    return unless supported_events.include?(data[:object_kind])

    return unless notify_label?(data)

    return unless webhook.present?

    object_kind = data[:object_kind]

    data = custom_data(data)

    # WebHook events often have an 'update' event that follows a 'open' or
    # 'close' action. Ignore update events for now to prevent duplicate
    # messages from arriving.

    message = get_message(object_kind, data)

    return false unless message

    event_type = data[:event_type] || object_kind

    channel_names = get_channel_field(event_type).presence || channel.presence
    channels = channel_names&.split(',')&.map(&:strip)

    opts = {}
    opts[:channel] = channels if channels.present?
    opts[:username] = username if username

    if notify(message, opts)
      log_usage(event_type, user_id_from_hook_data(data))
      return true
    end

    false
  end

  def event_channel_names
    supported_events.map { |event| event_channel_name(event) }
  end

  def event_field(event)
    fields.find { |field| field[:name] == event_channel_name(event) }
  end

  def global_fields
    fields.reject { |field| field[:name].end_with?('channel') }
  end

  def default_channel_placeholder
    raise NotImplementedError
  end

  private

  def log_usage(_, _)
    # Implement in child class
  end

  def labels_to_be_notified_list
    return [] if labels_to_be_notified.nil?

    labels_to_be_notified.delete('~').split(',').map(&:strip)
  end

  def notify_label?(data)
    return true unless SUPPORTED_EVENTS_FOR_LABEL_FILTER.include?(data[:object_kind]) && labels_to_be_notified.present?

    issue_labels = data.dig(:issue, :labels) || []
    merge_request_labels = data.dig(:merge_request, :labels) || []
    label_titles = (issue_labels + merge_request_labels).pluck(:title)

    (labels_to_be_notified_list & label_titles).any?
  end

  def user_id_from_hook_data(data)
    data.dig(:user, :id) || data[:user_id]
  end

  # every notifier must implement this independently
  def notify(message, opts)
    raise NotImplementedError
  end

  def custom_data(data)
    data.merge(project_url: project_url, project_name: project_name)
  end

  def get_message(object_kind, data)
    case object_kind
    when "push", "tag_push"
      ChatMessage::PushMessage.new(data) if notify_for_ref?(data)
    when "issue"
      ChatMessage::IssueMessage.new(data) unless update?(data)
    when "merge_request"
      ChatMessage::MergeMessage.new(data) unless update?(data)
    when "note"
      ChatMessage::NoteMessage.new(data)
    when "pipeline"
      ChatMessage::PipelineMessage.new(data) if should_pipeline_be_notified?(data)
    when "wiki_page"
      ChatMessage::WikiPageMessage.new(data)
    when "deployment"
      ChatMessage::DeploymentMessage.new(data)
    end
  end

  def get_channel_field(event)
    field_name = event_channel_name(event)
    self.public_send(field_name) # rubocop:disable GitlabSecurity/PublicSend
  end

  def build_event_channels
    supported_events.reduce([]) do |channels, event|
      channels << { type: 'text', name: event_channel_name(event), placeholder: default_channel_placeholder }
    end
  end

  def event_channel_name(event)
    EVENT_CHANNEL[event]
  end

  def project_name
    project.full_name
  end

  def project_url
    project.web_url
  end

  def update?(data)
    data[:object_attributes][:action] == 'update'
  end

  def should_pipeline_be_notified?(data)
    notify_for_ref?(data) && notify_for_pipeline?(data)
  end

  def notify_for_ref?(data)
    return true if data[:object_kind] == 'tag_push'
    return true if data.dig(:object_attributes, :tag)

    notify_for_branch?(data)
  end

  def notify_for_pipeline?(data)
    case data[:object_attributes][:status]
    when 'success'
      !notify_only_broken_pipelines?
    when 'failed'
      true
    else
      false
    end
  end
end
