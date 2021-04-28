# frozen_string_literal: true

module Sidebars
  module Projects
    module Menus
      class LearnGitlabMenu < ::Sidebars::Menu
        include Gitlab::Utils::StrongMemoize

        override :link
        def link
          project_learn_gitlab_path(context.project)
        end

        override :active_routes
        def active_routes
          { controller: :learn_gitlab }
        end

        override :title
        def title
          _('Learn GitLab')
        end

        override :has_pill?
        def has_pill?
          context.learn_gitlab_experiment_enabled
        end

        override :pill_count
        def pill_count
          strong_memoize(:pill_count) do
            "#{context.learn_gitlab_completed_percentage}%"
          end
        end

        override :extra_container_html_options
        def nav_link_html_options
          { class: 'home' }
        end

        override :image_path
        def image_path
          'learn_gitlab/graduation_hat.svg'
        end

        override :render?
        def render?
          context.learn_gitlab_experiment_enabled
        end
      end
    end
  end
end
