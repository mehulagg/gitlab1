# frozen_string_literal: true

module Gitlab
  module Graphql
    module Authorize
      class AuthorizeFieldService
        def initialize(field)
          @field = field
          @old_resolve_proc = @field.resolve_proc
        end

        def authorizations?
          authorizations.present?
        end

        def authorized_resolve
          proc do |parent_typed_object, args, ctx|
            if Feature.enabled?(:graphql_framework_authorization)
              @old_resolve_proc.call(parent_typed_object, args, ctx)
            else
              resolved_type = @old_resolve_proc.call(parent_typed_object, args, ctx)
              authorizing_object = authorize_against(parent_typed_object, resolved_type)

              filter_allowed(ctx[:current_user], resolved_type, authorizing_object)
            end
          end
        end

        private

        def authorizations
          @authorizations ||= (type_authorizations + field_authorizations).uniq
        end

        # Returns any authorize metadata from the return type of @field
        def type_authorizations
          type = @field.type

          # When the return type of @field is a collection, find the singular type
          if @field.connection?
            type = node_type_for_relay_connection(type)
          elsif type.list?
            type = node_type_for_basic_connection(type)
          end

          type = type.unwrap if type.kind.non_null?

          Array.wrap(type.metadata[:authorize])
        end

        # Returns any authorize metadata from @field
        def field_authorizations
          return [] if @field.metadata[:authorize] == true

          Array.wrap(@field.metadata[:authorize])
        end

        def authorize_against(parent_typed_object, resolved_type)
          if scalar_type?
            # The field is a built-in/scalar type, or a list of scalars
            # authorize using the parent's object
            parent_typed_object.object
          elsif @field.connection? || @field.type.list? || resolved_type.is_a?(Array)
            # The field is a connection or a list of non-built-in types, we'll
            # authorize each element when rendering
            nil
          elsif resolved_type.respond_to?(:object)
            # The field is a type representing a single object, we'll authorize
            # against the object directly
            resolved_type.object
          else
            # Resolved type is a single object that might not be loaded yet by
            # the batchloader, we'll authorize that
            resolved_type
          end
        end

        def filter_allowed(current_user, resolved_type, authorizing_object)
          if resolved_type.nil?
            # We're not rendering anything, for example when a record was not found
            # no need to do anything
          elsif authorizing_object
            # Authorizing fields representing scalars, or a simple field with an object
            ::Gitlab::Graphql::Lazy.with_value(authorizing_object) do |object|
              resolved_type if allowed_access?(current_user, object)
            end
          elsif @field.connection?
            ::Gitlab::Graphql::Lazy.with_value(resolved_type) do |type|
              # A connection with pagination, modify the visible nodes on the
              # connection type in place
              nodes = to_nodes(type)
              nodes.keep_if { |node| allowed_access?(current_user, node) } if nodes
              type
            end
          elsif @field.type.list? || resolved_type.is_a?(Array)
            # A simple list of rendered types  each object being an object to authorize
            ::Gitlab::Graphql::Lazy.with_value(resolved_type) do |items|
              items.select do |single_object_type|
                object_type = realized(single_object_type)
                object = object_type.try(:object) || object_type
                allowed_access?(current_user, object)
              end
            end
          else
            raise "Can't authorize #{@field}"
          end
        end

        # Ensure that we are dealing with realized objects, not delayed promises
        def realized(thing)
          ::Gitlab::Graphql::Lazy.force(thing)
        end

        # Try to get the connection
        # can be at type.object or at type
        def to_nodes(type)
          if type.respond_to?(:nodes)
            type.nodes
          elsif type.respond_to?(:object)
            to_nodes(type.object)
          else
            nil
          end
        end

        def allowed_access?(current_user, object)
          object = realized(object)

          authorizations.all? do |ability|
            Ability.allowed?(current_user, ability, object)
          end
        end

        # Returns the singular type for relay connections.
        # This will be the type class of edges.node
        def node_type_for_relay_connection(type)
          type.unwrap.get_field('edges').type.unwrap.get_field('node').type
        end

        # Returns the singular type for basic connections, for example `[Types::ProjectType]`
        def node_type_for_basic_connection(type)
          type.unwrap
        end

        def scalar_type?
          node_type_for_basic_connection(@field.type).kind.scalar?
        end
      end
    end
  end
end
