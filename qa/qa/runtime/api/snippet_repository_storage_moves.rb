# frozen_string_literal: true

module QA
  module Runtime
    module API
      module SnippetRepositoryStorageMoves
        extend self
        extend Support::Api

        SnippetRepositoryStorageMovesError = Class.new(RuntimeError)

        def has_status?(snippet, status, destination_storage = Env.additional_repository_storage)
          find_any do |move|
            next unless move[:snippet][:path_with_namespace] == snippet.path_with_namespace

            QA::Runtime::Logger.debug("Move data: #{move}")

            move[:state] == status &&
                move[:destination_storage_name] == destination_storage
          end
        end

        def find_any
          Logger.debug('Getting repository storage moves')

          Support::Waiter.wait_until do
            with_paginated_response_body(Request.new(api_client, '/snippet_repository_storage_moves', per_page: '100').url) do |page|
              break true if page.any? { |item| yield item }
            end
          end
        end

        private

        def api_client
          @api_client ||= Client.as_admin
        end
      end
    end
  end
end
