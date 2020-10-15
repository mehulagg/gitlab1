# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Upload a maven package', :api, :js do
  include_context 'file upload requests helpers'

  let_it_be(:project) { create(:project) }
  let_it_be(:user) { create(:user, :admin) }
  let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }

  let(:api_path) { "/projects/#{project.id}/packages/maven/com/example/my-app/1.0/my-app-1.0-20180724.124855-1.jar" }
  let(:url) { capybara_url(api(api_path, personal_access_token: personal_access_token)) }
  let(:file) { fixture_file_upload('spec/fixtures/dk.png') }

  subject { HTTParty.put(url, body: file.read) }

  RSpec.shared_examples 'for a maven package' do
    it 'creates package files' do
      expect { subject }
        .to change { Packages::Package.maven.count }.by(1)
        .and change { Packages::PackageFile.count }.by(1)
    end

    it { expect(subject.code).to eq(200) }
  end

  RSpec.shared_examples 'for a maven sha1' do
    let(:dummy_package) { double(Packages::Package) }
    let(:sha1) { Digest::SHA1.hexdigest('dummy_package') }
    let(:api_path) { "/projects/#{project.id}/packages/maven/com/example/my-app/1.0/my-app-1.0-20180724.124855-1.jar.sha1" }
    let(:file) { StringIO.new(sha1) }

    before do
      expect(::Packages::PackageFileFinder).to receive(:new).and_return(double(execute!: dummy_package))
      expect(dummy_package).to receive(:file_sha1).and_return(Digest::SHA1.hexdigest(sha1))
    end

    it { expect(subject.code).to eq(204) }
  end

  RSpec.shared_examples 'for a maven sha1' do
    let(:api_path) { "/projects/#{project.id}/packages/maven/com/example/my-app/1.0/my-app-1.0-20180724.124855-1.jar.md5" }
    let(:file) { StringIO.new('dummy_package') }

    it { expect(subject.code).to eq(200) }
  end

  it_behaves_like 'handling file uploads', 'for a maven package'
  it_behaves_like 'handling file uploads', 'for a maven sha1'
end
