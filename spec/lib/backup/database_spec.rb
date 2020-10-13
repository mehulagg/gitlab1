# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Backup::Database do
  let(:progress) { StringIO.new }
  let(:output) { progress.string }

  describe '#restore' do
    let(:cmd) { %W[#{Gem.ruby} -e $stdout.puts(1)] }
    let(:data) { Rails.root.join("spec/fixtures/pages_empty.tar.gz").to_s }

    subject { described_class.new(progress, filename: data) }

    before do
      allow(subject).to receive(:pg_restore_cmd).and_return(cmd)
    end

    context 'with an empty .gz file' do
      let(:data) { Rails.root.join("spec/fixtures/pages_empty.tar.gz").to_s }

      it 'returns successfully' do
        expect(subject.restore).to eq([])

        expect(output).to include("Restoring PostgreSQL database")
        expect(output).to include("[DONE]")
        expect(output).not_to include("ERRORS")
      end
    end

    context 'with a corrupted .gz file' do
      let(:data) { Rails.root.join("spec/fixtures/big-image.png").to_s }

      it 'raises a backup error' do
        expect { subject.restore }.to raise_error(Backup::Error)
      end
    end

    context 'when the restore command prints errors' do
      let(:visible_error) { "This is a test error\n" }
      let(:noise) { "Table projects does not exist\nmust be owner of extension pg_trgm\n" }
      let(:cmd) { %W[#{Gem.ruby} -e $stderr.write("#{noise}#{visible_error}")] }

      it 'filters out noise from errors' do
        expect(subject.restore).to eq([visible_error])
        expect(output).to include("ERRORS")
        expect(output).not_to include(noise)
        expect(output).to include(visible_error)
      end
    end
  end
end
