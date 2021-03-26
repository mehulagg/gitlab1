# frozen_string_literal: true

module Sidebars
  module Projects
    module Menus
      module ProjectOverview
        module MenuItems
          class Details < ::Sidebars::MenuItem
            override :item_link
            def item_link
              project_path(context.project)
            end

            override :extra_item_container_html_options
            def extra_item_container_html_options
              {
                title: _('Project details'),
                class: 'shortcuts-project'
              }
            end

            override :active_routes
            def active_routes
              { path: 'projects#show' }
            end

            override :item_name
            def item_name
              _('Details')
            end
          end
        end
      end
    end
  end
end
