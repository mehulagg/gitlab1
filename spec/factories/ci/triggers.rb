FactoryGirl.define do
  factory :ci_trigger_without_token, class: Ci::Trigger do
    factory :ci_trigger do
      token 'token'
    end
  end
end
