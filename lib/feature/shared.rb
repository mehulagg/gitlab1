# frozen_string_literal: true

# This file can contain only simple constructs as it is shared between:
# 1. `Pure Ruby`: `bin/feature-flag`
# 2. `GitLab Rails`: `lib/feature/definition.rb`

class Feature
  module Shared
    # optional: defines if a on-disk definition is required or optional for this feature flag type
    # auto_create: if definition is missing auto create it
    # rollout_issue: defines if `bin/feature-flag` asks for rollout issue
    # default_enabled: defines a default state of a feature flag when created by `bin/feature-flag`
    # ee_only: defines that a feature flag can only be created in a context of EE
    # example: usage being shown when exception is raised
    TYPES = {
      development: {
        description: 'Short lived, used to enable unfinished code to be deployed',
        optional: false,
        auto_create: false,
        rollout_issue: true,
        ee_only: false,
        default_enabled: false,
        example: <<-EOS
          Feature.enabled?(:my_feature_flag, project)
          Feature.enabled?(:my_feature_flag, project, type: :development)
          push_frontend_feature_flag?(:my_feature_flag, project)
        EOS
      },
      ops: {
        description: "Long-lived feature flags that control operational aspects of GitLab's behavior",
        optional: true,
        # Ops feature flags for are automatically created in non-CI environment
        auto_create: ENV['CI'] ? false : true,
        rollout_issue: false,
        ee_only: false,
        default_enabled: false,
        example: <<-EOS
          Feature.enabled?(:my_ops_flag, type: ops)
          push_frontend_feature_flag?(:my_ops_flag, project, type: :ops)
        EOS
      },
      licensed: {
        description: 'Permanent feature flags used to temporarily disable licensed features.',
        optional: true,
        auto_create: false,
        rollout_issue: false,
        ee_only: true,
        default_enabled: true,
        example: <<-EOS
          project.feature_available?(:my_licensed_feature)
          namespace.feature_available?(:my_licensed_feature)
        EOS
      }
    }.freeze

    # The ordering of PARAMS defines an order in YAML
    # This is done to ease the file comparison
    PARAMS = %i[
      name
      introduced_by_url
      rollout_issue_url
      type
      group
      default_enabled
    ].freeze
  end
end
