# frozen_string_literal: true

class UserCustomAttribute < NamespaceShard
  belongs_to :user

  validates :user_id, :key, :value, presence: true
  validates :key, uniqueness: { scope: [:user_id] }
end
