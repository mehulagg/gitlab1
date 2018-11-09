require 'spec_helper'

describe GitlabSubscription do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:seats) }
    it { is_expected.to validate_presence_of(:start_date) }
    it { is_expected.to validate_presence_of(:end_date) }

    it do
      subject.namespace = create(:namespace)
      is_expected.to validate_uniqueness_of(:namespace_id)
    end
  end

  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:hosted_plan) }
  end

  describe '#seats_in_use' do
    let!(:user_1)         { create(:user) }
    let!(:user_2)         { create(:user) }
    let!(:blocked_user)   { create(:user, :blocked) }
    let!(:user_namespace) { create(:user).namespace }
    let!(:user_project)   { create(:project, namespace: user_namespace) }

    let!(:group)               { create(:group) }
    let!(:subgroup_1)          { create(:group, parent: group) }
    let!(:subgroup_2)          { create(:group, parent: group) }
    let!(:gitlab_subscription) { create(:gitlab_subscription, namespace: group) }

    before do
      %i[free_plan bronze_plan silver_plan gold_plan].each do |plan|
        create(plan)
      end
    end

    it 'returns count of members' do
      group.add_developer(user_1)

      expect(gitlab_subscription.seats_in_use).to eq(1)
    end

    it 'also counts users from subgroups', :postgresql do
      group.add_developer(user_1)
      subgroup_1.add_developer(user_2)

      expect(gitlab_subscription.seats_in_use).to eq(2)
    end

    it 'does not count duplicated members', :postgresql do
      group.add_developer(user_1)
      subgroup_1.add_developer(user_2)
      subgroup_2.add_developer(user_2)

      expect(gitlab_subscription.seats_in_use).to eq(2)
    end

    it 'does not count blocked members' do
      group.add_developer(user_1)
      group.add_developer(blocked_user)

      expect(group.member_count).to eq(2)
      expect(gitlab_subscription.seats_in_use).to eq(1)
    end

    context 'with guest members' do
      before do
        group.add_guest(user_1)
      end

      context 'with a gold plan' do
        it 'excludes these members' do
          group.update!(plan: 'gold')

          expect(gitlab_subscription.seats_in_use).to eq(0)
        end
      end

      context 'with other plans' do
        %w[bronze silver].each do |plan|
          it 'excludes these members' do
            group.update!(plan: plan)

            expect(gitlab_subscription.seats_in_use).to eq(1)
          end
        end
      end
    end

    context 'when subscription is for a User' do
      before do
        gitlab_subscription.update!(namespace: user_namespace)

        user_project.add_developer(user_1)
        user_project.add_developer(user_2)
      end

      it 'always returns 1 seat' do
        %w[bronze silver gold].each do |plan|
          user_namespace.update!(plan: plan)

          expect(gitlab_subscription.seats_in_use).to eq(1)
        end
      end
    end
  end
end
