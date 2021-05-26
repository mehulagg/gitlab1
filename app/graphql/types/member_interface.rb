# frozen_string_literal: true

module Types
  module MemberInterface
    include BaseInterface

    field :id, GraphQL::ID_TYPE, null: false,
          description: 'ID of the member.'

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

    field :user, Types::UserType, null: false,
          description: 'User that is associated with the member object.'

    field :invite_source, GraphQL::STRING_TYPE, null: true,
          description: 'Source that triggered the member creation process. See https://gitlab.com/gitlab-org/gitlab/-/issues/327120.'

    definition_methods do
      def resolve_type(object, context)
        case object
        when GroupMember
          Types::GroupMemberType
        when ProjectMember
          Types::ProjectMemberType
        else
          raise ::Gitlab::Graphql::Errors::BaseError, "Unknown member type #{object.class.name}"
        end
      end
    end
  end
end
