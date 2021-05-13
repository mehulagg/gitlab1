# frozen_string_literal: true

class SmartcardIdentity < NamespaceShard
  belongs_to :user

  validates :user,
            presence: true
  validates :subject,
            presence: true,
            uniqueness: { scope: :issuer }
  validates :issuer,
            presence: true
end
