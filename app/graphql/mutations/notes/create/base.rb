# frozen_string_literal: true

module Mutations
  module Notes
    module Create
      # This is a Base class for the Note creation Mutations and is not
      # mounted as a GraphQL mutation itself.
      class Base < Mutations::Notes::Base
        authorize :create_note

        argument :noteable_id,
                 ::Types::GlobalIDType[::Noteable],
                  required: true,
                  description: 'The global ID of the resource to add a note to.'

        argument :body,
                  GraphQL::STRING_TYPE,
                  required: true,
                  description: copy_field_description(Types::Notes::NoteType, :body)

        argument :confidential,
                  GraphQL::BOOLEAN_TYPE,
                  required: false,
                  description: 'The confidentiality flag of a note. Default is false.'

        def resolve(args)
          noteable = authorized_find!(id: args[:noteable_id])
          verify_rate_limit!(current_user)

          note = ::Notes::CreateService.new(
            noteable.project,
            current_user,
            create_note_params(noteable, args)
          ).execute

          {
            note: (note if note.persisted?),
            errors: errors_on_object(note)
          }
        end

        private

        def find_object(id:)
          # TODO: remove explicit coercion once compatibility layer has been removed
          # See: https://gitlab.com/gitlab-org/gitlab/-/issues/257883
          id = ::Types::GlobalIDType[::Noteable].coerce_isolated_input(id)
          GitlabSchema.find_by_gid(id)
        end

        def create_note_params(noteable, args)
          {
            noteable: noteable,
            note: args[:body],
            confidential: args[:confidential]
          }
        end

        def verify_rate_limit!(current_user)
          rate_limiter, key = ::Gitlab::ApplicationRateLimiter, :notes_create
          return unless rate_limiter.throttled?(key, scope: [current_user])

          raise Gitlab::Graphql::Errors::ResourceNotAvailable,
            'This endpoint has been requested too many times. Try again later.'
        end
      end
    end
  end
end
