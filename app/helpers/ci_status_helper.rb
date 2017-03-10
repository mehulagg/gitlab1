module CiStatusHelper
  def ci_status_path(pipeline)
    project = pipeline.project
    namespace_project_pipeline_path(project.namespace, project, pipeline)
  end

  # Is used by Commit and Merge Request Widget
  def ci_label_for_status(status)
    if detailed_status?(status)
      return status.label
    end

    case status
    when 'success'
      'passed'
    when 'success_with_warnings'
      'passed with warnings'
    else
      status
    end
  end

  def ci_status_for_statuseable(subject)
    status = subject.try(:status) || 'not found'
    status.humanize
  end

  def ci_icon_for_status(status)
    if detailed_status?(status)
      return custom_icon(status.icon)
    end

    icon_name =
      case status
      when 'success'
        'icon_status_success'
      when 'success_with_warnings'
        'icon_status_warning'
      when 'failed'
        'icon_status_failed'
      when 'pending'
        'icon_status_pending'
      when 'running'
        'icon_status_running'
      when 'play'
        'icon_play'
      when 'created'
        'icon_status_created'
      when 'skipped'
        'icon_status_skipped'
      when 'manual'
        'icon_status_manual'
      else
        'icon_status_canceled'
      end

    custom_icon(icon_name)
  end

  def render_commit_status(commit, ref: nil, tooltip_placement: 'auto left')
    project = commit.project
    path = pipelines_namespace_project_commit_path(
      project.namespace,
      project,
      commit)

    render_status_with_link(
      'commit',
      commit.status(ref),
      path,
      tooltip_placement: tooltip_placement)
  end

  def render_pipeline_status(pipeline, tooltip_placement: 'auto left')
    project = pipeline.project
    path = namespace_project_pipeline_path(project.namespace, project, pipeline)
    render_status_with_link('pipeline', pipeline.status, path, tooltip_placement: tooltip_placement)
  end

  def no_runners_for_project?(project)
    project.runners.blank? &&
      Ci::Runner.shared.blank?
  end

  def render_status_with_link(type, status, path = nil, tooltip_placement: 'auto left', cssclass: '', container: 'body')
    klass = "ci-status-link ci-status-icon-#{status.dasherize} #{cssclass}"
    title = "#{type.titleize}: #{ci_label_for_status(status)}"
    data = { toggle: 'tooltip', placement: tooltip_placement, container: container }

    if path
      link_to ci_icon_for_status(status), path,
              class: klass, title: title, data: data
    else
      content_tag :span, ci_icon_for_status(status),
              class: klass, title: title, data: data
    end
  end

  def detailed_status?(status)
    status.respond_to?(:text) &&
      status.respond_to?(:label) &&
      status.respond_to?(:icon)
  end
end
