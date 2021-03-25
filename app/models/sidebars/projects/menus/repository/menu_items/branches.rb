# frozen_string_literal: true

module Sidebars
  module Projects
    module Menus
      module Repository
        module MenuItems
          class Branches < ::Sidebars::MenuItem
            override :link_to_href
            def link_to_href
              project_branches_path(context.project)
            end

            override :link_to_attributes
            def link_to_attributes
              {
                data: { qa_selector: 'branches_link' },
                id: 'js-onboarding-branches-link'
              }
            end

            override :nav_link_params
            def nav_link_params
              { controller: :branches }
            end

            override :item_name
            def item_name
              _('Branches')
            end
          end
        end
      end
    end
  end
end
