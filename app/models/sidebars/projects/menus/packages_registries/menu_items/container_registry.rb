# frozen_string_literal: true

module Sidebars
  module Projects
    module Menus
      module PackagesRegistries
        module MenuItems
          class ContainerRegistry < ::Sidebars::MenuItem
            override :link
            def link
              project_container_registry_index_path(context.project)
            end

            override :extra_container_html_options
            def extra_container_html_options
              {
                class: 'shortcuts-container-registry'
              }
            end

            override :active_routes
            def active_routes
              { controller: :repositories }
            end

            override :title
            def title
              _('Container Registry')
            end

            override :render?
            def render?
              ::Gitlab.config.registry.enabled &&
                can?(context.current_user, :read_container_image, context.project)
            end
          end
        end
      end
    end
  end
end
