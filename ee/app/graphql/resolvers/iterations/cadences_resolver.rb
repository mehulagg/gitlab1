# frozen_string_literal: true

module Resolvers
  module Iterations
    class CadencesResolver < BaseResolver
      include Gitlab::Graphql::CopyFieldDescription
      include Gitlab::Graphql::Authorize::AuthorizeResource

      argument :id, ::Types::GlobalIDType[::Iterations::Cadence], required: false,
        description: 'Global ID of the Iteration to look up.'

      argument :title, GraphQL::STRING_TYPE, required: false,
        description: 'Fuzzy search by title.'

      argument :duration_in_weeks, GraphQL::INT_TYPE, required: false,
        description: copy_field_description(Types::Iterations::CadenceType, :duration_in_weeks)

      argument :automatic, GraphQL::BOOLEAN_TYPE, required: false,
        description: copy_field_description(Types::Iterations::CadenceType, :automatic)

      argument :active, GraphQL::BOOLEAN_TYPE, required: false,
        description: copy_field_description(Types::Iterations::CadenceType, :active)

      argument :include_ancestor_groups, GraphQL::BOOLEAN_TYPE, required: false,
        description: 'Whether to include ancestor groups to search iterations cadences in.'

      type ::Types::Iterations::CadenceType.connection_type, null: true

      def resolve(**args)
        authorize!

        cadences = ::Iterations::CadencesFinder.new(context[:current_user], group, args).execute

        offset_pagination(cadences)
      rescue ::Iterations::CadencesFinder::ResourceNotFoundError => ex
        raise_resource_not_available_error!(ex.message)
      end

      private

      def group
        @parent ||= object.respond_to?(:sync) ? object.sync : object

        case @parent
        when Group
          @parent
        when Project
          raise raise_resource_not_available_error!('The project does not have a parent group. Iteration cadences are only supported only at group level.') if @parent.group.blank?

          @parent.group
        else raise "Unexpected parent type: #{@parent.class}"
        end
      end

      def authorize!
        Ability.allowed?(context[:current_user], :read_iterations_cadence, group) || raise_resource_not_available_error!
      end
    end
  end
end
