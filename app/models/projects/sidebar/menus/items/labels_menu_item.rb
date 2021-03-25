# frozen_string_literal: true

module Projects
  module Sidebar
    module Menus
      module Items
        class LabelsMenuItem < ::Sidebar::MenuItem
          override :link_to_href
          def link_to_href
            project_labels_path(context.project)
          end

          override :link_to_attributes
          def link_to_attributes
            {
              title: _('Labels'),
              class: 'qa-labels-link'
            }
          end

          override :nav_link_params
          def nav_link_params
            { controller: :labels }
          end

          override :item_name
          def item_name
            _('Labels')
          end
        end
      end
    end
  end
end
