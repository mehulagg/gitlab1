# frozen_string_literal: true

require 'securerandom'

module QA
  module Resource
    class Label < LabelBase
      attribute :project do
        Project.fabricate! do |resource|
          resource.name = 'project-with-label'
        end
      end

      def fabricate!
        project.visit!
        Page::Project::Menu.perform(&:go_to_labels)

        super
      end

      def api_post_path
        "/projects/#{project.id}/labels"
      end

      def api_get_path
        raise("Instance of label was created without id, unable to fetch label data!") unless id

        "/projects/#{project.id}/labels/#{id}"
      end
    end
  end
end
