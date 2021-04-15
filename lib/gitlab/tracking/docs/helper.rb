# frozen_string_literal: true

module Gitlab
  module Tracking
    module Docs
      # Helper with functions to be used by HAML templates
      module Helper
        def auto_generated_comment
          <<-MARKDOWN.strip_heredoc
            ---
            stage: Growth
            group: Product Intelligence
            info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#designated-technical-writers
            ---

            <!---
              This documentation is auto generated by a script.

              Please do not edit this file directly, check generate_metrics_dictionary task on lib/tasks/gitlab/usage_data.rake.
            --->

            <!-- vale gitlab.Spelling = NO -->
          MARKDOWN
        end

        def render_name(name)
          "### `#{name}`"
        end

        def render_description(object)
          return 'Missing description' unless object[:description].present?

          object[:description]
        end

        def render_object_schema(object)
          "[Object JSON schema](#{object.json_schema_path})"
        end

        def render_yaml_link(yaml_path)
          "[YAML definition](#{yaml_path})"
        end

        def render_status(object)
          "Status: #{format(:status, object[:status])}"
        end

        def render_owner(object)
          "Group: `#{object[:product_group]}`"
        end

        def render_tiers(object)
          "Tiers:#{format(:tier, object[:tier])}"
        end

        def format(key, value)
          Gitlab::Usage::Docs::ValueFormatter.format(key, value)
        end
      end
    end
  end
end
