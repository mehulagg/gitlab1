# frozen_string_literal: true

# This class extracts all users found in a piece of text by the username or the
# email address

module Gitlab
  class UserExtractor
    # Not using `Devise.email_regexp` to filter out any chars that an email
    # does not end with and not pinning the email to a start of end of a string.
    EMAIL_REGEXP = /(?<email>([^@\s]+@[^@\s]+(?<!\W)))/
    USERNAME_REGEXP = User.reference_pattern

    def initialize(text)
      @text = text.is_a?(Array) ? text.join(' ') : text
    end

    def users
      return User.none unless @text.present?

      @users ||= User.from_union(union_relations)
    end

    def usernames
      matches[:usernames]
    end

    def emails
      matches[:emails]
    end

    def references
      @references ||= matches.values.flatten
    end

    def matches
      @matches ||= {
        emails: @text.scan(EMAIL_REGEXP).flatten.uniq,
        usernames: @text.scan(USERNAME_REGEXP).flatten.uniq
      }
    end

    private

    def union_relations
      relations = []

      relations << User.by_any_email(emails) if emails.any?
      relations << User.by_username(usernames) if usernames.any?

      relations
    end
  end
end
