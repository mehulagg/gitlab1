require 'spec_helper'

describe ChatMessage::MergeMessage, models: true do
  subject { described_class.new(args) }

  let(:args) do
    {
      user: {
          name: 'Test User',
          username: 'test.user',
          avatar_url: 'http://someavatar.com'
      },
      project_name: 'project_name',
      project_url: 'http://somewhere.com',

      object_attributes: {
        title: "Merge Request title\nSecond line",
        id: 10,
        iid: 100,
        assignee_id: 1,
        url: 'http://url.com',
        state: 'opened',
        description: 'merge request description',
        source_branch: 'source_branch',
        target_branch: 'target_branch',
      }
    }
  end

  context 'without markdown' do
    let(:color) { '#345' }

    context 'open' do
      it 'returns a message regarding opening of merge requests' do
        expect(subject.pretext).to eq(
          'test.user opened <http://somewhere.com/merge_requests/100|!100 *Merge Request title*> in <http://somewhere.com|project_name>: *Merge Request title*')
        expect(subject.attachments).to be_empty
      end
    end

    context 'close' do
      before do
        args[:object_attributes][:state] = 'closed'
      end
      it 'returns a message regarding closing of merge requests' do
        expect(subject.pretext).to eq(
          'test.user closed <http://somewhere.com/merge_requests/100|!100 *Merge Request title*> in <http://somewhere.com|project_name>: *Merge Request title*')
        expect(subject.attachments).to be_empty
      end
    end
  end

  context 'approval' do
    before do
      args[:object_attributes][:action] = 'approved'
    end

    it 'returns a message regarding approval of merge requests' do
      expect(subject.pretext).to eq(
        'test.user approved <http://somewhere.com/merge_requests/100|!100 *Merge Request title*> '\
        'in <http://somewhere.com|project_name>: *Merge Request title*')
      expect(subject.attachments).to be_empty
    end
  end

  context 'with markdown' do
    before do
      args[:markdown] = true
    end

    context 'open' do
      it 'returns a message regarding opening of merge requests' do
        expect(subject.pretext).to eq(
          'test.user opened [!100 *Merge Request title*](http://somewhere.com/merge_requests/100) in [project_name](http://somewhere.com): *Merge Request title*')
        expect(subject.attachments).to be_empty
        expect(subject.activity).to eq({
          title: 'Merge Request opened by test.user',
          subtitle: 'in [project_name](http://somewhere.com)',
          text: '[!100 *Merge Request title*](http://somewhere.com/merge_requests/100)',
          image: 'http://someavatar.com'
        })
      end
    end

    context 'close' do
      before do
        args[:object_attributes][:state] = 'closed'
      end

      it 'returns a message regarding closing of merge requests' do
        expect(subject.pretext).to eq(
          'test.user closed [!100 *Merge Request title*](http://somewhere.com/merge_requests/100) in [project_name](http://somewhere.com): *Merge Request title*')
        expect(subject.attachments).to be_empty
        expect(subject.activity).to eq({
          title: 'Merge Request closed by test.user',
          subtitle: 'in [project_name](http://somewhere.com)',
          text: '[!100 *Merge Request title*](http://somewhere.com/merge_requests/100)',
          image: 'http://someavatar.com'
        })
      end
    end
  end
end
