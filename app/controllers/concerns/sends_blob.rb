# frozen_string_literal: true

module SendsBlob
  extend ActiveSupport::Concern

  included do
    include BlobHelper
    include SendFileUpload
  end

  def send_blob(repository, blob, inline: nil, version: nil)
    if blob
      headers['X-Content-Type-Options'] = 'nosniff'

      return if cached_blob?(blob, version: version)

      if blob.stored_externally?
        send_lfs_object(blob, version: version)
      else
        send_git_blob(repository, blob, inline: inline)
      end
    else
      render_404
    end
  end

  private

  def cached_blob?(blob, version: nil)
    etag = [blob.id, version].join

    stale = stale?(etag: etag) # The #stale? method sets cache headers.

    # Because we are opinionated we set the cache headers ourselves.
    response.cache_control[:public] = project.public?

    response.cache_control[:max_age] =
      if @ref && @commit && @ref == @commit.id # rubocop:disable Gitlab/ModuleWithInstanceVariables
        # This is a link to a commit by its commit SHA. That means that the blob
        # is immutable. The only reason to invalidate the cache is if the commit
        # was deleted or if the user lost access to the repository.
        Blob::CACHE_TIME_IMMUTABLE
      else
        # A branch or tag points at this blob. That means that the expected blob
        # value may change over time.
        Blob::CACHE_TIME
      end

    response.etag = etag
    !stale
  end

  def send_lfs_object(blob, version: nil)
    lfs_object = find_lfs_object(blob)

    return render_404 unless lfs_object && lfs_object.project_allowed_access?(project)

    if version
      namespace, version = version.values_at(:namespace, :version)

      # Uncomment this to have the images generated in this request:
      #
      # lfs_object.file.enable_version_namespace(namespace)
      # lfs_object.file.recreate_versions!

      lfs_object_file = lfs_object.file.version(namespace, version)
    else
      lfs_object_file = lfs_object.file
    end

    send_upload(lfs_object_file, attachment: blob.name)
  end

  def find_lfs_object(blob)
    lfs_object = LfsObject.find_by_oid(blob.lfs_oid)
    if lfs_object && lfs_object.file.exists?
      lfs_object
    else
      nil
    end
  end
end
