require 'spec_helper'

describe Gitlab::Ci::Pipeline::Chain::Build do
  set(:project) { create(:project, :repository) }
  set(:user) { create(:user) }
  let(:pipeline) { Ci::Pipeline.new }

  let(:variables_attributes) do
    [{ key: 'first', secret_value: 'world' },
     { key: 'second', secret_value: 'second_world' }]
  end
  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(
      source: :push,
      origin_ref: 'master',
      checkout_sha: project.commit.id,
      after_sha: nil,
      before_sha: nil,
      trigger_request: nil,
      schedule: nil,
      project: project,
      current_user: user,
      variables_attributes: variables_attributes)
  end

  let(:step) { described_class.new(pipeline, command) }

  before do
    stub_repository_ci_yaml_file(sha: anything)
  end

  it 'never breaks the chain' do
    step.perform!

    expect(step.break?).to be false
  end

  it 'fills pipeline object with data' do
    step.perform!

    expect(pipeline.sha).not_to be_empty
    expect(pipeline.sha).to eq project.commit.id
    expect(pipeline.ref).to eq 'master'
    expect(pipeline.tag).to be false
    expect(pipeline.user).to eq user
    expect(pipeline.project).to eq project
    expect(pipeline.variables.map { |var| var.slice(:key, :secret_value) })
      .to eq variables_attributes.map(&:with_indifferent_access)
  end

  it 'returns a valid pipeline' do
    step.perform!

    expect(pipeline).to be_valid
  end

  it 'does not persist a pipeline' do
    step.perform!

    expect(pipeline).not_to be_persisted
  end

  context 'when pipeline is running for a tag' do
    let(:command) do
      Gitlab::Ci::Pipeline::Chain::Command.new(
        source: :push,
        origin_ref: 'mytag',
        checkout_sha: project.commit.id,
        after_sha: nil,
        before_sha: nil,
        trigger_request: nil,
        schedule: nil,
        project: project,
        current_user: user)
    end

    before do
      allow_any_instance_of(Repository).to receive(:tag_exists?).with('mytag').and_return(true)

      step.perform!
    end

    it 'correctly indicated that this is a tagged pipeline' do
      expect(pipeline).to be_tag
    end
  end
end
