# frozen_string_literal: true

module MirrorHelper
  def mirrors_form_data_attributes
    {
      project_mirror_ssh_endpoint: ssh_host_keys_project_mirror_path(@project, :json),
      project_mirror_endpoint: project_mirror_path(@project, :json)
    }
  end
end

MirrorHelper.prepend(EE::MirrorHelper)
