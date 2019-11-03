# frozen_string_literal: true

module Gitlab
  module Ci
    module Pipeline
      module Chain
        class Base
          attr_reader :pipeline, :command, :config

          delegate :project, :current_user, to: :command

          def initialize(pipeline, command, config)
            @pipeline = pipeline
            @command = command
            @config = config
          end

          def perform!
            raise NotImplementedError
          end

          def break?
            raise NotImplementedError
          end
        end
      end
    end
  end
end
