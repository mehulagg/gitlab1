# frozen_string_literal: true

module Types
  module InvitationInterface
    include BaseInterface

    field :email, GraphQL::STRING_TYPE, null: false,
          description: 'Email of the member to invite.'

    field :access_level, Types::AccessLevelType, null: true,
          description: 'GitLab::Access level.'

    field :created_by, Types::UserType, null: true,
          description: 'User that authorized membership.'

    field :created_at, Types::TimeType, null: true,
          description: 'Date and time the membership was created.'

    field :updated_at, Types::TimeType, null: true,
          description: 'Date and time the membership was last updated.'

    field :expires_at, Types::TimeType, null: true,
          description: 'Date and time the membership expires.'

    field :user, Types::UserType, null: true,
          description: 'User that is associated with the member object.'

    field :invite_source, GraphQL::STRING_TYPE, null: true,
          description: 'Source that triggered the member creation process.'

    definition_methods do
      def resolve_type(object, context)
        case object
        when GroupMember
          Types::GroupInvitationType
        when ProjectMember
          Types::ProjectInvitationType
        else
          raise ::Gitlab::Graphql::Errors::BaseError, "Unknown member type #{object.class.name}"
        end
      end
    end
  end
end
