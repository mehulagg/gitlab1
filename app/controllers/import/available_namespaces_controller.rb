# frozen_string_literal: true

class Import::AvailableNamespacesController < ApplicationController
  def index
    render json: NamespaceSerializer.new.represent(current_user.manageable_groups_with_routes)
  end
end
