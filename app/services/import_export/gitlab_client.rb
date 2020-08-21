module ImportExport
  class GitlabClient
    attr_reader :host, :access_token

    def initialize(host:, access_token:)
      @host = host
      @access_token = access_token
    end

    def start_export(group_id:)
      Gitlab::HTTP.post(start_export_url(group_id),
        # body: content,
        allow_local_requests: true,
        headers: headers)
    end

    private

    def start_export_url(group_id)
      "#{host}/api/v4/groups/#{group_id}/bulk_export"
    end

    def headers
      {
        'Content-Type' => 'application/json',
        'PRIVATE-TOKEN' => access_token
      }
    end
  end
end
