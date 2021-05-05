# frozen_string_literal: true

module Gitlab
  module Email
    module Handler
      module ReplyProcessing
        private

        attr_reader :project_id, :project_slug, :project_path, :incoming_email_token

        def author
          raise NotImplementedError
        end

        # rubocop:disable Gitlab/ModuleWithInstanceVariables
        def project
          return @project if instance_variable_defined?(:@project)

          if project_id
            @project = Project.find_by_id(project_id)
            @project = nil unless valid_project_slug?(@project)
          else
            @project = Project.find_by_full_path(project_path)
          end

          @project
        end
        # rubocop:enable Gitlab/ModuleWithInstanceVariables

        def message
          @message ||= process_message
        end

        def message_including_reply
          @message_with_reply ||= process_message(trim_reply: false)
        end

        def process_message(**kwargs)
          message = ReplyParser.new(mail, **kwargs).execute.strip
          message_with_attachments = add_attachments(message)

          # Support bot is specifically forbidden
          # from using slash commands.
          strip_quick_actions(message_with_attachments)
        end

        def add_attachments(reply)
          attachments = Email::AttachmentUploader.new(mail).execute(**upload_params)

          reply + attachments.map do |link|
            "\n\n#{link[:markdown]}"
          end.join
        end

        def upload_params
          {
            upload_parent: project,
            uploader_class: FileUploader
          }
        end

        def validate_permission!(permission)
          raise UserNotFoundError unless author
          raise UserBlockedError if author.blocked?

          if project
            raise ProjectNotFound unless author.can?(:read_project, project)
          end

          raise UserNotAuthorizedError unless author.can?(permission, try(:noteable) || project)
        end

        def verify_record!(record:, invalid_exception:, record_name:)
          return if record.persisted?
          return if record.errors.key?(:commands_only)

          error_title = "The #{record_name} could not be created for the following reasons:"

          msg = error_title + record.errors.full_messages.map do |error|
            "\n\n- #{error}"
          end.join

          raise invalid_exception, msg
        end

        def valid_project_slug?(found_project)
          project_slug == found_project.full_path_slug
        end

        def strip_quick_actions(content)
          return content unless author.support_bot?

          command_definitions = ::QuickActions::InterpretService.command_definitions
          extractor = ::Gitlab::QuickActions::Extractor.new(command_definitions)

          extractor.redact_commands(content)
        end
      end
    end
  end
end

Gitlab::Email::Handler::ReplyProcessing.prepend_mod_with('::EE::Gitlab::Email::Handler::ReplyProcessing')
