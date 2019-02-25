# frozen_string_literal: true

class Snippets::NotesController < ApplicationController
  include NotesActions
  include ToggleAwardEmoji

  skip_before_action :authenticate_user!, only: [:index]
  before_action :snippet
  before_action :authorize_read_snippet!, only: [:show, :index, :create]

  private

  def note
    @note ||= snippet.notes.inc_relations_for_view.find(params[:id])
  end
  alias_method :awardable, :note

  def project
    nil
  end

  # rubocop: disable CodeReuse/ActiveRecord
  def snippet
    PersonalSnippet.find_by(id: params[:snippet_id])
  end
  # rubocop: enable CodeReuse/ActiveRecord
  alias_method :noteable, :snippet

  def finder_params
    params.merge(last_fetched_at: last_fetched_at, target_id: snippet.id, target_type: 'personal_snippet')
  end

  def authorize_read_snippet!
    return render_404 unless can?(current_user, :read_personal_snippet, snippet)
  end
end
