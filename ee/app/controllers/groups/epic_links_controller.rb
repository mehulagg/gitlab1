# frozen_string_literal: true

class Groups::EpicLinksController < Groups::ApplicationController
  include EpicRelations

  before_action :check_epics_available!, only: :index
  before_action :check_subepics_available!, only: [:create, :destroy, :update]

  def update
    result = EpicLinks::UpdateService.new(child_epic, current_user, params[:epic]).execute

    render json: { message: result[:message] }, status: result[:http_status]
  end

  def destroy
    result = ::EpicLinks::DestroyService.new(child_epic, current_user).execute

    render json: { issuables: issuables }, status: result[:http_status]
  end

  private

  def create_service
    EpicLinks::CreateService.new(epic, current_user, create_params)
  end

  def list_service
    EpicLinks::ListService.new(epic, current_user)
  end

  def child_epic
    @child_epic ||= Epic.find(params[:id])
  end

  def authorized_object
    'epic_link'
  end
end
