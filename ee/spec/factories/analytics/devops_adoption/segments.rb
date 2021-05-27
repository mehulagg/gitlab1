# frozen_string_literal: true

FactoryBot.define do
  factory :devops_adoption_segment, class: 'Analytics::DevopsAdoption::Segment' do
    association :namespace, factory: :group

    after(:build) do |instance|
      instance.display_namespace = instance.namespace
    end
  end
end
