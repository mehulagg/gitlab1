require 'spec_helper'

describe GeoNodeStatusEntity, :postgresql do
  let(:geo_node_status) { build(:geo_node_status) }
  let(:entity) { described_class.new(geo_node_status, request: double) }
  let(:error) { 'Could not connect to Geo database' }

  subject { entity.as_json }

  it { is_expected.to have_key(:geo_node_id) }
  it { is_expected.to have_key(:healthy) }
  it { is_expected.to have_key(:health) }
  it { is_expected.to have_key(:attachments_count) }
  it { is_expected.to have_key(:attachments_failed_count) }
  it { is_expected.to have_key(:attachments_synced_count) }
  it { is_expected.to have_key(:attachments_synced_in_percentage) }
  it { is_expected.to have_key(:lfs_objects_count) }
  it { is_expected.to have_key(:lfs_objects_failed_count) }
  it { is_expected.to have_key(:lfs_objects_synced_count) }
  it { is_expected.to have_key(:lfs_objects_synced_in_percentage) }
  it { is_expected.to have_key(:repositories_count) }
  it { is_expected.to have_key(:repositories_failed_count) }
  it { is_expected.to have_key(:repositories_synced_count)}
  it { is_expected.to have_key(:repositories_synced_in_percentage) }
  it { is_expected.to have_key(:ci_traces_count) }
  it { is_expected.to have_key(:ci_traces_failed_count) }
  it { is_expected.to have_key(:ci_traces_synced_count)}
  it { is_expected.to have_key(:ci_traces_synced_in_percentage) }
  it { is_expected.to have_key(:last_successful_status_check_timestamp) }
  it { is_expected.to have_key(:namespaces) }

  describe '#healthy' do
    context 'when node is healthy' do
      it 'returns true' do
        expect(subject[:healthy]).to eq true
      end
    end

    context 'when node is unhealthy' do
      before do
        geo_node_status.health = error
      end

      subject { entity.as_json }

      it 'returns false' do
        expect(subject[:healthy]).to eq false
      end
    end
  end

  describe '#health' do
    context 'when node is healthy' do
      it 'exposes the health message' do
        expect(subject[:health]).to eq 'Healthy'
      end
    end

    context 'when node is unhealthy' do
      before do
        geo_node_status.health = error
      end

      subject { entity.as_json }

      it 'exposes the error message' do
        expect(subject[:health]).to eq error
      end
    end
  end

  describe '#attachments_synced_in_percentage' do
    it 'formats as percentage' do
      geo_node_status.assign_attributes(attachments_count: 329,
                                        attachments_failed_count: 25,
                                        attachments_synced_count: 141)

      expect(subject[:attachments_synced_in_percentage]).to eq '42.86%'
    end
  end

  describe '#lfs_objects_synced_in_percentage' do
    it 'formats as percentage' do
      geo_node_status.assign_attributes(lfs_objects_count: 256,
                                        lfs_objects_failed_count: 12,
                                        lfs_objects_synced_count: 123)

      expect(subject[:lfs_objects_synced_in_percentage]).to eq '48.05%'
    end
  end

  describe '#repositories_synced_in_percentage' do
    it 'formats as percentage' do
      geo_node_status.assign_attributes(repositories_count: 10,
                                        repositories_synced_count: 5,
                                        repositories_failed_count: 0)

      expect(subject[:repositories_synced_in_percentage]).to eq '50.00%'
    end
  end

  describe '#ci_traces_synced_in_percentage' do
    it 'formats as percentage' do
      geo_node_status.assign_attributes(ci_traces_count: 10,
                                        ci_traces_synced_count: 5,
                                        ci_traces_failed_count: 0)

      expect(subject[:ci_traces_synced_in_percentage]).to eq '50.00%'
    end
  end

  describe '#namespaces' do
    it 'returns empty array when full sync is active' do
      expect(subject[:namespaces]).to be_empty
    end

    it 'returns array of namespace ids and paths for selective sync' do
      namespace = create(:namespace)
      geo_node_status.geo_node.namespaces << namespace

      expect(subject[:namespaces]).not_to be_empty
      expect(subject[:namespaces]).to be_an(Array)
      expect(subject[:namespaces].first[:id]).to eq(namespace.id)
      expect(subject[:namespaces].first[:path]).to eq(namespace.path)
    end
  end
end
