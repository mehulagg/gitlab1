# == Schema Information
#
# Table name: services
#
#  id         :integer          not null, primary key
#  type       :string(255)
#  title      :string(255)
#  project_id :integer
#  created_at :datetime
#  updated_at :datetime
#  active     :boolean          default(FALSE), not null
#  properties :text
#  template   :boolean          default(FALSE)
#

require 'spec_helper'

describe Service do

  describe "Associations" do
    it { is_expected.to belong_to :project }
    it { is_expected.to have_one :service_hook }
  end

  describe "Mass assignment" do
  end

  describe "Test Button" do
    before do
      @service = Service.new
    end

    describe "Testable" do
      let (:project) { create :project }

      before do
        @service.stub(
          project: project
        )
        @testable = @service.can_test?
      end

      describe :can_test do
        it { expect(@testable).to eq(true) }
      end
    end

    describe "With commits" do
      let (:project) { create :project }

      before do
        @service.stub(
          project: project
        )
        @testable = @service.can_test?
      end

      describe :can_test do
        it { expect(@testable).to eq(true) }
      end
    end
  end

  describe "Available services" do
    it { expect(Service.available_services_names).to  include("jenkins", "jira")}
  end

  describe "Template" do
    describe "for pushover service" do
      let(:service_template) {
        PushoverService.create(template: true, properties: {device: 'MyDevice', sound: 'mic', priority: 4, api_key: '123456789'})
      }
      let(:project) { create(:project) }

      describe 'should be prefilled for projects pushover service' do
        before do
          service_template
          project.build_missing_services
        end

        it "should have all fields prefilled" do
          service = project.pushover_service
          expect(service.template).to eq(false)
          expect(service.device).to eq('MyDevice')
          expect(service.sound).to eq('mic')
          expect(service.priority).to eq(4)
          expect(service.api_key).to eq('123456789')
        end
      end
    end
  end
end
