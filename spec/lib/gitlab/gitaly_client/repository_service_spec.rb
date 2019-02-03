require 'spec_helper'

describe Gitlab::GitalyClient::RepositoryService do
  using RSpec::Parameterized::TableSyntax

  let(:project) { create(:project) }
  let(:storage_name) { project.repository_storage }
  let(:relative_path) { project.disk_path + '.git' }
  let(:client) { described_class.new(project.repository) }

  describe '#exists?' do
    it 'sends a repository_exists message' do
      expect_any_instance_of(Gitaly::RepositoryService::Stub)
        .to receive(:repository_exists)
        .with(gitaly_request_with_path(storage_name, relative_path), kind_of(Hash))
        .and_return(double(exists: true))

      client.exists?
    end
  end

  describe '#cleanup' do
    it 'sends a cleanup message' do
      expect_any_instance_of(Gitaly::RepositoryService::Stub)
        .to receive(:cleanup)
        .with(gitaly_request_with_path(storage_name, relative_path), kind_of(Hash))

      client.cleanup
    end
  end

  describe '#garbage_collect' do
    it 'sends a garbage_collect message' do
      expect_any_instance_of(Gitaly::RepositoryService::Stub)
        .to receive(:garbage_collect)
        .with(gitaly_request_with_path(storage_name, relative_path), kind_of(Hash))
        .and_return(double(:garbage_collect_response))

      client.garbage_collect(true)
    end
  end

  describe '#repack_full' do
    it 'sends a repack_full message' do
      expect_any_instance_of(Gitaly::RepositoryService::Stub)
        .to receive(:repack_full)
        .with(gitaly_request_with_path(storage_name, relative_path), kind_of(Hash))
        .and_return(double(:repack_full_response))

      client.repack_full(true)
    end
  end

  describe '#repack_incremental' do
    it 'sends a repack_incremental message' do
      expect_any_instance_of(Gitaly::RepositoryService::Stub)
        .to receive(:repack_incremental)
        .with(gitaly_request_with_path(storage_name, relative_path), kind_of(Hash))
        .and_return(double(:repack_incremental_response))

      client.repack_incremental
    end
  end

  describe '#repository_size' do
    it 'sends a repository_size message' do
      expect_any_instance_of(Gitaly::RepositoryService::Stub)
        .to receive(:repository_size)
        .with(gitaly_request_with_path(storage_name, relative_path), kind_of(Hash))
        .and_return(size: 0)

      client.repository_size
    end
  end

  describe '#apply_gitattributes' do
    let(:revision) { 'master' }

    it 'sends an apply_gitattributes message' do
      expect_any_instance_of(Gitaly::RepositoryService::Stub)
        .to receive(:apply_gitattributes)
        .with(gitaly_request_with_path(storage_name, relative_path), kind_of(Hash))
        .and_return(double(:apply_gitattributes_response))

      client.apply_gitattributes(revision)
    end
  end

  describe '#info_attributes' do
    it 'reads the info attributes' do
      expect_any_instance_of(Gitaly::RepositoryService::Stub)
        .to receive(:get_info_attributes)
        .with(gitaly_request_with_path(storage_name, relative_path), kind_of(Hash))
        .and_return([])

      client.info_attributes
    end
  end

  describe '#has_local_branches?' do
    it 'sends a has_local_branches message' do
      expect_any_instance_of(Gitaly::RepositoryService::Stub)
        .to receive(:has_local_branches)
        .with(gitaly_request_with_path(storage_name, relative_path), kind_of(Hash))
        .and_return(double(value: true))

      expect(client.has_local_branches?).to be(true)
    end
  end

  describe '#fetch_remote' do
    let(:remote) { 'remote-name' }

    it 'sends a fetch_remote_request message' do
      expected_request = gitaly_request_with_params(
        remote: remote,
        ssh_key: '',
        known_hosts: '',
        force: false,
        no_tags: false,
        no_prune: false
      )

      expect_any_instance_of(Gitaly::RepositoryService::Stub)
        .to receive(:fetch_remote)
        .with(expected_request, kind_of(Hash))
        .and_return(double(value: true))

      client.fetch_remote(remote, ssh_auth: nil, forced: false, no_tags: false, timeout: 1)
    end

    context 'SSH auth' do
      where(:ssh_mirror_url, :ssh_key_auth, :ssh_private_key, :ssh_known_hosts, :expected_params) do
        false | false | 'key' | 'known_hosts' | {}
        false | true  | 'key' | 'known_hosts' | {}
        true  | false | 'key' | 'known_hosts' | { known_hosts: 'known_hosts' }
        true  | true  | 'key' | 'known_hosts' | { ssh_key: 'key', known_hosts: 'known_hosts' }
        true  | true  | 'key' | nil           | { ssh_key: 'key' }
        true  | true  | nil   | 'known_hosts' | { known_hosts: 'known_hosts' }
        true  | true  | nil   | nil           | {}
        true  | true  | ''    | ''            | {}
      end

      with_them do
        let(:ssh_auth) do
          double(
            :ssh_auth,
            ssh_mirror_url?: ssh_mirror_url,
            ssh_key_auth?: ssh_key_auth,
            ssh_private_key: ssh_private_key,
            ssh_known_hosts: ssh_known_hosts
          )
        end

        it do
          expected_request = gitaly_request_with_params({
            remote: remote,
            ssh_key: '',
            known_hosts: '',
            force: false,
            no_tags: false,
            no_prune: false
          }.update(expected_params))

          expect_any_instance_of(Gitaly::RepositoryService::Stub)
            .to receive(:fetch_remote)
            .with(expected_request, kind_of(Hash))
            .and_return(double(value: true))

          client.fetch_remote(remote, ssh_auth: ssh_auth, forced: false, no_tags: false, timeout: 1)
        end
      end
    end
  end

  describe '#rebase_in_progress?' do
    let(:rebase_id) { 1 }

    it 'sends a repository_rebase_in_progress message' do
      expect_any_instance_of(Gitaly::RepositoryService::Stub)
        .to receive(:is_rebase_in_progress)
        .with(gitaly_request_with_path(storage_name, relative_path), kind_of(Hash))
        .and_return(double(in_progress: true))

      client.rebase_in_progress?(rebase_id)
    end
  end

  describe '#squash_in_progress?' do
    let(:squash_id) { 1 }

    it 'sends a repository_squash_in_progress message' do
      expect_any_instance_of(Gitaly::RepositoryService::Stub)
        .to receive(:is_squash_in_progress)
        .with(gitaly_request_with_path(storage_name, relative_path), kind_of(Hash))
        .and_return(double(in_progress: true))

      client.squash_in_progress?(squash_id)
    end
  end

  describe '#calculate_checksum' do
    it 'sends a calculate_checksum message' do
      expect_any_instance_of(Gitaly::RepositoryService::Stub)
        .to receive(:calculate_checksum)
        .with(gitaly_request_with_path(storage_name, relative_path), kind_of(Hash))
        .and_return(double(checksum: 0))

      client.calculate_checksum
    end
  end

  describe '#create_from_snapshot' do
    it 'sends a create_repository_from_snapshot message' do
      expect_any_instance_of(Gitaly::RepositoryService::Stub)
        .to receive(:create_repository_from_snapshot)
        .with(gitaly_request_with_path(storage_name, relative_path), kind_of(Hash))
        .and_return(double)

      client.create_from_snapshot('http://example.com?wiki=1', 'Custom xyz')
    end
  end

  describe '#raw_changes_between' do
    it 'sends a create_repository_from_snapshot message' do
      expect_any_instance_of(Gitaly::RepositoryService::Stub)
        .to receive(:get_raw_changes)
        .with(gitaly_request_with_path(storage_name, relative_path), kind_of(Hash))
        .and_return(double)

      client.raw_changes_between('deadbeef', 'deadpork')
    end
  end

  describe '#pre_fetch' do
    it 'sends a pre_fetch message' do
      fork_repository = Gitlab::Git::Repository.new('default', TEST_REPO_PATH, '', 'group/project')
      object_pool = create(:pool_repository).object_pool.gitaly_object_pool

      expect_any_instance_of(Gitaly::RepositoryService::Stub)
        .to receive(:pre_fetch)
        .with(kind_of(Gitaly::PreFetchRequest), kind_of(Hash))
        .and_return(double)

      client.pre_fetch(fork_repository, object_pool)
    end
  end
end
