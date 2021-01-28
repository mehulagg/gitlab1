# frozen_string_literal: true

module Gitlab
  module Database
    module BackgroundMigration
      class PrimaryKeyBatchingStrategy
        include Gitlab::Database::DynamicModelHelpers

        def next_batch(table_name, column_name, batch_size:, previous_max_value:)
          model_class = define_batchable_model(table_name)

          quoted_column_name = model_class.connection.quote_column_name(column_name)

          relation = model_class.where("#{quoted_column_name} >= ?", previous_max_value)

          relation.each_batch(of: batch_size, column: column_name) do |batch|
            return batch.pluck(Arel.sql("MIN(#{quoted_column_name}), MAX(#{quoted_column_name})")).first
          end

          nil
        end
      end
    end
  end
end
