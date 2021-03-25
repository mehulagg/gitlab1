# frozen_string_literal: true

module Sidebars
  class Menu
    extend ::Gitlab::Utils::Override
    include ::Gitlab::Routing
    include GitlabRoutingHelper
    include Gitlab::Allowable
    include ::Sidebars::Linkable
    include ::Sidebars::HasPill

    attr_reader :context
    delegate :current_user, :container, to: :@context

    def initialize(context)
      @context = context
      @items = []

      configure_menu_items
    end

    def configure_menu_items
      # No-op
    end

    def render?
      true
    end

    # This method normalizes the information retrieved from the submenus and this menu
    # Value from menus is something like: [{ path: 'foo', path: 'bar', controller: :foo }]
    # This method filters the information and returns: { path: ['foo', 'bar'], controller: :foo }
    def all_nav_link_params
      @all_nav_link_params ||= begin
        ([nav_link_params] + renderable_items.map(&:nav_link_params)).flatten.each_with_object({}) do |pairs, hash|
          pairs.each do |k, v|
            hash[k] ||= []
            hash[k] += Array(v)
            hash[k].uniq!
          end

          hash
        end
      end
    end

    def nav_link_params
      {}
    end

    def menu_name_html_options
      {}
    end

    def menu_name
      raise NotImplementedError
    end

    def has_items?
      @items.any?
    end

    def has_renderable_items?
      renderable_items.any?
    end

    def add_item(item)
      @items << item
    end

    def renderable_items
      @renderable_items ||= @items.select(&:render?)
    end

    def sprite_icon
      nil
    end

    def image_path
      nil
    end

    def image_html_options
      {}
    end

    def icon_or_image?
      sprite_icon || image_path
    end
  end
end
