# frozen_string_literal: true

module Gitlab
  module Database
    module Migrations
      module Observers
        class QueryLog < MigrationObserver
          def before
            @logger_was = ActiveRecord::Base.logger
            @log_file_path = File.join(Instrumentation::RESULT_DIR, 'current.log')
            @logger = Logger.new(@log_file_path)
            ActiveRecord::Base.logger = @logger
          end

          def after
            ActiveRecord::Base.logger = @logger_was
            @logger.close
          end

          def record(observation)
            File.rename(@log_file_path, File.join(Instrumentation::RESULT_DIR, "#{observation.version}_#{observation.name}.log"))
          end
        end
      end
    end
  end
end
