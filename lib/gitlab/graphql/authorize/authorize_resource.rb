# frozen_string_literal: true

module Gitlab
  module Graphql
    module Authorize
      module AuthorizeResource
        extend ActiveSupport::Concern

        RESOURCE_ACCESS_ERROR = "The resource that you are attempting to access does not exist or you don't have permission to perform this action"

        class_methods do
          def required_permissions
            # If the `#authorize` call is used on multiple classes, we add the
            # permissions specified on a subclass, to the ones that were specified
            # on it's superclass.
            @required_permissions ||= if self.respond_to?(:superclass) && superclass.respond_to?(:required_permissions)
                                        superclass.required_permissions.dup
                                      else
                                        []
                                      end
          end

          def authorize(*permissions)
            required_permissions.concat(permissions)
          end
        end

        def find_object(*args)
          raise NotImplementedError, "Implement #find_object in #{self.class.name}"
        end

        def authorized_find!(*args)
          object = Graphql::Lazy.force(find_object(*args))

          authorize!(object)

          object
        end

        def authorize!(object)
          unless Types::BaseObject.authorized?(object, context)
            raise_resource_not_available_error!
          end
        end

        def raise_resource_not_available_error!
          raise Gitlab::Graphql::Errors::ResourceNotAvailable, RESOURCE_ACCESS_ERROR
        end
      end
    end
  end
end
