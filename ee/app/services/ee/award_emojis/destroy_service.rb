# frozen_string_literal: true

module EE
  module AwardEmojis
    module DestroyService
      extend ::Gitlab::Utils::Override

      private

      override :after_destroy
      def after_destroy(award)
        super

        ::Gitlab::StatusPage.trigger_publish(project, current_user, award)
        track_epic_emoji_removed if awardable.is_a?(Epic)
      end

      def track_epic_emoji_removed
        ::Gitlab::UsageDataCounters::EpicActivityUniqueCounter.track_epic_emoji_removed_action(author: current_user)
      end
    end
  end
end
