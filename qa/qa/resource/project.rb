# frozen_string_literal: true

require 'securerandom'

module QA
  module Resource
    class Project < Base
      include Events::Project
      include Members
      include Visibility

      attr_accessor :repository_storage # requires admin access
      attr_writer :initialize_with_readme
      attr_writer :auto_devops_enabled

      attribute :id
      attribute :name
      attribute :add_name_uuid
      attribute :description
      attribute :standalone
      attribute :runners_token
      attribute :visibility
      attribute :template_name

      attribute :group do
        Group.fabricate!
      end

      attribute :path_with_namespace do
        "#{sandbox_path}#{group.path}/#{name}" if group
      end

      def sandbox_path
        group.respond_to?('sandbox') ? "#{group.sandbox.path}/" : ''
      end

      attribute :repository_ssh_location do
        Page::Project::Show.perform do |show|
          show.repository_clone_ssh_location
        end
      end

      attribute :repository_http_location do
        Page::Project::Show.perform do |show|
          show.repository_clone_http_location
        end
      end

      def initialize
        @add_name_uuid = true
        @standalone = false
        @description = 'My awesome project'
        @initialize_with_readme = false
        @auto_devops_enabled = false
        @visibility = :public
        @template_name = nil
      end

      def name=(raw_name)
        @name = @add_name_uuid ? "#{raw_name}-#{SecureRandom.hex(8)}" : raw_name
      end

      def fabricate!
        unless @standalone
          group.visit!
          Page::Group::Show.perform(&:go_to_new_project)
        end

        if @template_name
          Page::Project::New.perform do |new_page|
            new_page.click_create_from_template_tab
            new_page.use_template_for_project(@template_name)
          end
        end

        Page::Project::New.perform do |new_page|
          new_page.choose_test_namespace
          new_page.choose_name(@name)
          new_page.add_description(@description)
          new_page.set_visibility(@visibility)
          new_page.enable_initialize_with_readme if @initialize_with_readme
          new_page.create_new_project
        end
      end

      def fabricate_via_api!
        resource_web_url(api_get)
      rescue ResourceNotFoundError
        super
      end

      def api_get_path
        "/projects/#{CGI.escape(path_with_namespace)}"
      end

      def api_visibility_path
        "/projects/#{id}"
      end

      def api_get_archive_path(type = 'tar.gz')
        "#{api_get_path}/repository/archive.#{type}"
      end

      def api_members_path
        "#{api_get_path}/members"
      end

      def api_runners_path
        "#{api_get_path}/runners"
      end

      def api_repository_branches_path
        "#{api_get_path}/repository/branches"
      end

      def api_pipelines_path
        "#{api_get_path}/pipelines"
      end

      def api_put_path
        "/projects/#{id}"
      end

      def api_post_path
        '/projects'
      end

      def api_post_body
        post_body = {
          name: name,
          description: description,
          visibility: @visibility,
          initialize_with_readme: @initialize_with_readme,
          auto_devops_enabled: @auto_devops_enabled
        }

        unless @standalone
          post_body[:namespace_id] = group.id
          post_body[:path] = name
        end

        post_body[:repository_storage] = repository_storage if repository_storage
        post_body[:template_name] = @template_name if @template_name

        post_body
      end

      def change_repository_storage(new_storage)
        put_body = { repository_storage: new_storage }
        response = put Runtime::API::Request.new(api_client, api_put_path).url, put_body

        unless response.code == HTTP_STATUS_OK
          raise ResourceUpdateFailedError, "Could not change repository storage to #{new_storage}. Request returned (#{response.code}): `#{response}`."
        end

        wait_until do
          reload!

          api_response[:repository_storage] == new_storage
        end
      end

      def import_status
        response = get Runtime::API::Request.new(api_client, "/projects/#{id}/import").url

        unless response.code == HTTP_STATUS_OK
          raise ResourceQueryError, "Could not get import status. Request returned (#{response.code}): `#{response}`."
        end

        result = parse_body(response)

        Runtime::Logger.error("Import failed: #{result[:import_error]}") if result[:import_status] == "failed"

        result[:import_status]
      end

      def runners(tag_list: nil)
        response = get Runtime::API::Request.new(api_client, "#{api_runners_path}?tag_list=#{tag_list.compact.join(',')}").url
        parse_body(response)
      end

      def repository_branches
        response = get Runtime::API::Request.new(api_client, api_repository_branches_path).url
        parse_body(response)
      end

      def pipelines
        parse_body(get(Runtime::API::Request.new(api_client, api_pipelines_path).url))
      end

      def share_with_group(invitee, access_level = Resource::Members::AccessLevel::DEVELOPER)
        post Runtime::API::Request.new(api_client, "/projects/#{id}/share").url, { group_id: invitee.id, group_access: access_level }
      end

      private

      def transform_api_resource(api_resource)
        api_resource[:repository_ssh_location] =
          Git::Location.new(api_resource[:ssh_url_to_repo])
        api_resource[:repository_http_location] =
          Git::Location.new(api_resource[:http_url_to_repo])
        api_resource
      end
    end
  end
end
