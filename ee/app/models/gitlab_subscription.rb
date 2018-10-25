class GitlabSubscription < ActiveRecord::Base
  belongs_to :namespace

  validates :seats, :start_date, :end_date, :plan_code, :plan_name,
    presence: true
  validates :namespace_id, uniqueness: true, allow_blank: true
end
