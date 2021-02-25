# frozen_string_literal: true

# Provides a way to work around Rails issue where dependent objects are all
# loaded into memory before destroyed: https://github.com/rails/rails/issues/22510.
#
# This concern allows an ActiveRecord module to destroy all its dependent
# associations in batches. The idea is borrowed from https://github.com/thisismydesign/batch_dependent_associations.
#
# The differences here with that gem:
#
# 1. We allow excluding certain associations.
# 2. We don't need to support delete_all since we can use the EachBatch concern.
module BatchDestroyDependentAssociations
  extend ActiveSupport::Concern

  DEPENDENT_ASSOCIATIONS_BATCH_SIZE = 1000

  def dependent_associations_to_destroy
    self.class.reflect_on_all_associations(:has_many).select do |assoc|
      assoc.options[:dependent] == :destroy || assoc.klass.include?(FastDestroyAll)
    end
  end

  def destroy_dependent_associations_in_batches(exclude: [])
    dependent_associations_to_destroy.each do |association|
      next if exclude.include?(association.name)

      public_send(association.name).in_batches( # rubocop:disable Cop/InBatches, GitlabSecurity/PublicSend
        of: DEPENDENT_ASSOCIATIONS_BATCH_SIZE,
        &method(:destroy_dependent_association_in_batches)
      )
    end
  end

  private

  def destroy_dependent_association_in_batches(batch)
    if batch.klass.include? FastDestroyAll
      batch.fast_destroy_all # With batched fast destroy callbacks (not N + 1)
    elsif batch.klass.delete_callbacks_required?
      # rubocop:disable Cop/DestroyAll
      batch.destroy_all # For models with callbacks (N + 1)
      # rubocop:enable Cop/DestroyAll
    else
      batch.delete_all # For Models with no callbacks (not N + 1)
    end
  end
end
