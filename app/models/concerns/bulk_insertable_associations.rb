# frozen_string_literal: true

module BulkInsertableAssociations
  extend ActiveSupport::Concern

  MissingAssociationError = Class.new(StandardError)
  NotBulkInsertSafeError = Class.new(StandardError)

  class_methods do
    def supports_bulk_insert?(association)
      association_class_for(association) < BulkInsertSafe
    end

    def bulk_insert_on_save(association, items)
      unless supports_bulk_insert?(association)
        raise NotBulkInsertSafeError.new("#{association} does not support bulk inserts")
      end

      pending_association_items[association] ||= []
      pending_association_items[association] += items
    end

    # Returns a hash of association symbols mapped to a list of AR instances
    # that had been flushed. Method calls are idempotent.
    def flush_pending_bulk_inserts(model_instance)
      return {} unless pending_association_items&.any?

      pending_association_items.each do |association, items|
        attributes = get_validated_attributes(items, model_instance, association)
        association_class = association_class_for(association)
        association_class.insert_all(attributes)
      end
    ensure
      clear_pending_association_items
    end

    def validate_pending_bulk_inserts(model_instance)
      pending_association_items.each do |key, items|
        items.each do |item|
          unless item.valid?
            item.errors.full_messages.each do |item_error|
              model_instance.errors.add(key, item_error)
            end
          end
        end
      end
    end

    private

    def pending_association_items
      bulk_insert_context[self] ||= {}
    end

    def clear_pending_association_items
      bulk_insert_context.delete(self)
    end

    def bulk_insert_context
      Thread.current['_bulk_insert_context'] ||= {}
    end

    def get_validated_attributes(items, model_instance, association)
      all_attributes = []
      items.each do |item|
        all_attributes << process_item_attributes!(item.attributes, model_instance, association)
      end

      all_attributes
    end

    def process_item_attributes!(attributes, model_instance, association)
      drop_nil_id!(attributes)
      set_foreign_key!(attributes, model_instance, association)
      attributes
    end

    # removes any `id` fields that are nil since these won't insert cleanly
    def drop_nil_id!(attributes)
      attributes.delete('id') unless attributes['id']
    end

    # wires up the foreign key column with the owner of this association
    def set_foreign_key!(attributes, model_instance, association)
      owner_id_attribute = reflections[association.to_s].foreign_key
      attributes[owner_id_attribute] = model_instance.id
    end

    def association_class_for(association)
      reflection = reflect_on_association(association)
      unless reflection
        raise MissingAssociationError.new("#{self} does not define association #{association}")
      end

      reflection.klass
    end
  end

  def validate_pending_bulk_inserts
    self.class.validate_pending_bulk_inserts(self)
  end

  included do
    delegate :bulk_insert_on_save, to: self
    delegate :flush_pending_bulk_inserts, to: self

    validate :validate_pending_bulk_inserts

    after_save { flush_pending_bulk_inserts(self) }
  end
end
