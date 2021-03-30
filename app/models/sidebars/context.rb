# frozen_string_literal: true

module Sidebars
  class Context
    attr_reader :current_user, :container

    def initialize(current_user:, container:, **args)
      @current_user = current_user
      @container = container

      args.each do |key, value|
        singleton_class.public_send :attr_reader, key # rubocop:disable GitlabSecurity/PublicSend
        instance_variable_set("@#{key}", value)
      end
    end
  end
end
