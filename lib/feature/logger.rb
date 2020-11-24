# frozen_string_literal: true

module Feature
  class Logger < ::Gitlab::JsonLogger
    def self.file_name_noext
      'features'
    end
  end
end
