# frozen_string_literal: true

# NuGet Package Manager Client API
#
# These API endpoints are not meant to be consumed directly by users. They are
# called by the NuGet package manager client when users run commands
# like `nuget install` or `nuget push`.
#
# This is the project level API.
module API
  class NugetProjectPackages < ::API::Base
    helpers ::API::Helpers::PackagesHelpers
    helpers ::API::Helpers::Packages::BasicAuthHelpers
    include ::API::Helpers::Authentication

    feature_category :package_registry

    PACKAGE_FILENAME = 'package.nupkg'

    default_format :json

    authenticate_with do |accept|
      accept.token_types(:personal_access_token, :deploy_token, :job_token)
            .sent_through(:http_basic_auth)
    end

    rescue_from ArgumentError do |e|
      render_api_error!(e.message, 400)
    end

    after_validation do
      require_packages_enabled!
    end

    helpers do
      def project_or_group
        authorized_user_project
      end
    end

    params do
      requires :id, type: String, desc: 'The ID of a project', regexp: ::API::Concerns::Packages::NugetEndpoints::POSITIVE_INTEGER_REGEX
    end
    resource :projects, requirements: API::NAMESPACE_OR_PROJECT_REQUIREMENTS do
      namespace ':id/packages/nuget' do
        include ::API::Concerns::Packages::NugetEndpoints

        # https://docs.microsoft.com/en-us/nuget/api/package-publish-resource
        desc 'The NuGet Package Publish endpoint' do
          detail 'This feature was introduced in GitLab 12.6'
        end

        params do
          requires :package, type: ::API::Validations::Types::WorkhorseFile, desc: 'The package file to be published (generated by Multipart middleware)'
        end
        put do
          authorize_upload!(project_or_group)
          bad_request!('File is too large') if project_or_group.actual_limits.exceeded?(:nuget_max_file_size, params[:package].size)

          file_params = params.merge(
            file: params[:package],
            file_name: PACKAGE_FILENAME
          )

          package = ::Packages::Nuget::CreatePackageService.new(project_or_group, current_user, declared_params.merge(build: current_authenticated_job))
                                                           .execute

          package_file = ::Packages::CreatePackageFileService.new(package, file_params.merge(build: current_authenticated_job))
                                                             .execute

          track_package_event('push_package', :nuget, category: 'API::NugetPackages')

          ::Packages::Nuget::ExtractionWorker.perform_async(package_file.id) # rubocop:disable CodeReuse/Worker

          created!
        rescue ObjectStorage::RemoteStoreError => e
          Gitlab::ErrorTracking.track_exception(e, extra: { file_name: params[:file_name], project_id: project_or_group.id })

          forbidden!
        end
        put 'authorize' do
          authorize_workhorse!(
            subject: project_or_group,
            has_length: false,
            maximum_size: project_or_group.actual_limits.nuget_max_file_size
          )
        end

        # https://docs.microsoft.com/en-us/nuget/api/package-base-address-resource
        params do
          requires :package_name, type: String, desc: 'The NuGet package name', regexp: API::NO_SLASH_URL_PART_REGEX
        end
        namespace '/download/*package_name' do
          after_validation do
            authorize_read_package!(project_or_group)
          end

          desc 'The NuGet Content Service - index request' do
            detail 'This feature was introduced in GitLab 12.8'
          end
          get 'index', format: :json do
            present ::Packages::Nuget::PackagesVersionsPresenter.new(find_packages(params[:package_name])),
                    with: ::API::Entities::Nuget::PackagesVersions
          end

          desc 'The NuGet Content Service - content request' do
            detail 'This feature was introduced in GitLab 12.8'
          end
          params do
            requires :package_version, type: String, desc: 'The NuGet package version', regexp: API::NO_SLASH_URL_PART_REGEX
            requires :package_filename, type: String, desc: 'The NuGet package filename', regexp: API::NO_SLASH_URL_PART_REGEX
          end
          get '*package_version/*package_filename', format: :nupkg do
            filename = "#{params[:package_filename]}.#{params[:format]}"
            package_file = ::Packages::PackageFileFinder.new(find_package(params[:package_name], params[:package_version]), filename, with_file_name_like: true)
                                                        .execute

            not_found!('Package') unless package_file

            track_package_event('pull_package', :nuget, category: 'API::NugetPackages')

            # nuget and dotnet don't support 302 Moved status codes, supports_direct_download has to be set to false
            present_carrierwave_file!(package_file.file, supports_direct_download: false)
          end
        end
      end
    end
  end
end
