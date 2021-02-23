# frozen_string_literal: true

FactoryBot.define do
  factory :group_wiki_repository do
    group

    after(:build) do |group_wiki_repository, _|
      group_wiki_repository.shard_name = group_wiki_repository.repository_storage
      group_wiki_repository.disk_path  = group_wiki_repository.disk_path
    end

    # trait(:checksummed) do
    #   verification_checksum { 'abc' }
    # end

    # trait(:checksum_failure) do
    #   verification_failure { 'Could not calculate the checksum' }
    # end
  end
end
