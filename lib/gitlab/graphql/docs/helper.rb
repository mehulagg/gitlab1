# frozen_string_literal: true

return if Rails.env.production?

module Gitlab
  module Graphql
    module Docs
      FIELD_HEADER = <<~MD
        #### fields
        
        | name | type | description |
        | ---- | ---- | ----------- |
      MD

      ARG_HEADER = <<~MD
        # arguments
        
        | name | type | description |
        | ---- | ---- | ----------- |
      MD

      # Helper with functions to be used by HAML templates
      # This includes graphql-docs gem helpers class.
      # You can check the included module on: https://github.com/gjtorikian/graphql-docs/blob/v1.6.0/lib/graphql-docs/helpers.rb
      module Helper
        include GraphQLDocs::Helpers

        def auto_generated_comment
          <<-MD.strip_heredoc
            ---
            stage: Plan
            group: Project Management
            info: To determine the technical writer assigned to the Stage/Group associated with this page, see https://about.gitlab.com/handbook/engineering/ux/technical-writing/#designated-technical-writers
            ---

            <!---
              This documentation is auto generated by a script.

              Please do not edit this file directly, check compile_docs task on lib/tasks/gitlab/graphql.rake.
            --->
          MD
        end

        def render_full_field(field, level = 3)
          arg_header = ('#' * level) + ARG_HEADER
          [
            render_name_and_description(field, level),
            render_return_type(field),
            render_field_table(arg_header, field[:arguments])
          ].compact.join("\n\n")
        end

        def render_field_table(header, fields)
          return if fields.empty?

          header + fields.map { |f| render_field(f) }.join("\n")
        end

        def render_object_fields(fields)
          return if fields.empty?

          (simple, has_args) = fields.partition { |f| f[:arguments].empty? }

          [simple_fields(simple), fields_with_arguments(has_args)].compact.join("\n\n")
        end

        def simple_fields(fields)
          render_field_table(FIELD_HEADER, sorted_by_name(fields))
        end

        def fields_with_arguments(fields)
          return if fields.empty?

          <<~MD.chomp
            #### fields with arguments

            #{sorted_by_name(fields).map { |f| render_full_field(f, 5) }.join("\n\n")}
          MD
        end

        def render_name_and_description(object, level = 3)
          content = ["#{'#' * level} `#{object[:name]}`"]

          if object[:description].present?
            desc = object[:description]
            desc += '.' unless object[:description].ends_with?('.')
            content << desc
          end

          content.join("\n\n")
        end

        def sorted_by_name(objects)
          return [] unless objects.present?

          objects.sort_by { |o| o[:name] }
        end

        def render_field(field)
          row(render_name(field), render_field_type(field[:type]), render_description(field))
        end

        def render_enum_value(value)
          row(render_name(value), render_description(value))
        end

        def row(*values)
          "| #{values.join(' | ')} |"
        end

        def render_name(object)
          rendered_name = "`#{object[:name]}`"
          rendered_name += ' **{warning-solid}**' if object[:is_deprecated]
          rendered_name
        end

        # Returns the object description. If the object has been deprecated,
        # the deprecation reason will be returned in place of the description.
        def render_description(object)
          return object[:description] unless object[:is_deprecated]

          "**Deprecated:** #{object[:deprecation_reason]}"
        end

        # Some fields types are arrays of other types and are displayed
        # on docs wrapped in square brackets, for example: [String!].
        # This makes GitLab docs renderer thinks they are links so here
        # we change them to be rendered as: String! => Array.
        def render_field_type(type)
          "[`#{type[:info]}`](##{type[:name].downcase})"
        end

        def render_return_type(query)
          "Returns #{render_field_type(query[:type])}"
        end

        # We are ignoring connections and built in types for now,
        # they should be added when queries are generated.
        def objects
          object_types = graphql_object_types.select do |object_type|
            !object_type[:name]["__"]
          end

          object_types.each do |type|
            type[:fields] += type[:connections]
          end
        end

        def queries
          graphql_operation_types.find { |type| type[:name] == 'Query' }.to_h.values_at(:fields, :connections).flatten
        end

        # We ignore the built-in enum types.
        def enums
          graphql_enum_types.select do |enum_type|
            !enum_type[:name].in?(%w[__DirectiveLocation __TypeKind])
          end
        end
      end
    end
  end
end
