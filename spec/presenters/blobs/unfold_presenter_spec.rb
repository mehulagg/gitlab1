# frozen_string_literal: true

require 'spec_helper'

describe Blobs::UnfoldPresenter do
  include FakeBlobHelpers

  let(:project) { create(:project, :repository) }
  let(:blob) { fake_blob(path: 'foo', data: "1\n2\n3") }
  let(:subject) { described_class.new(blob, params) }

  describe '#initialize' do
    context 'when full is false' do
      let(:params) { { full: false, since: 2, to: 3, bottom: false, offset: 1, indent: 1 } }

      it 'sets attributes' do
        result = subject

        expect(result.full?).to eq(false)
        expect(result.since).to eq(2)
        expect(result.to).to eq(3)
        expect(result.bottom).to eq(false)
        expect(result.offset).to eq(1)
        expect(result.indent).to eq(1)
      end
    end

    context 'when full is true' do
      let(:params) { { full: true, since: 2, to: 3, bottom: false, offset: 1, indent: 1 } }

      it 'sets other attributes' do
        result = subject

        expect(result.full?).to eq(true)
        expect(result.since).to eq(1)
        expect(result.to).to eq(blob.lines.size)
        expect(result.bottom).to eq(false)
        expect(result.offset).to eq(0)
        expect(result.indent).to eq(0)
      end
    end
  end

  describe '#diff_lines' do
    let(:total_lines) { 50 }
    let(:blob) { fake_blob(path: 'foo', data: (1..total_lines).to_a.join("\n")) }

    context 'when "full" is true' do
      let(:params) { { full: true } }

      it 'returns all lines' do
        lines = subject.diff_lines

        expect(lines.size).to eq(total_lines)

        lines.each.with_index do |line, index|
          expect(line.text).to include("LC#{index + 1}")
          expect(line.text).to eq(line.rich_text)
          expect(line.type).to be_nil
        end
      end

      context 'when last line is empty' do
        let(:blob) { fake_blob(path: 'foo', data: "1\n2\n") }

        it 'disregards last line' do
          lines = subject.diff_lines

          expect(lines.size).to eq(2)
        end
      end
    end

    context 'when "since" is equal to 1' do
      let(:params) { { since: 1, to: 10, offset: 10 } }

      it 'does not add top match line' do
        line = subject.diff_lines.first

        expect(line.type).to be_nil
      end
    end

    context 'when since is greater than 1' do
      let(:params) { { since: 5, to: 10, offset: 10 } }

      it 'adds top match line' do
        line = subject.diff_lines.first

        expect(line.type).to eq('match')
        expect(line.old_pos).to eq(5)
        expect(line.new_pos).to eq(5)
      end
    end

    context 'when "to" is less than blob size' do
      let(:params) { { since: 1, to: 5, offset: 10, bottom: true } }

      it 'adds bottom match line' do
        line = subject.diff_lines.last

        expect(line.type).to eq('match')
        expect(line.old_pos).to eq(-5)
        expect(line.new_pos).to eq(5)
      end
    end

    context 'when "to" is equal to blob size' do
      let(:params) { { since: 1, to: total_lines, offset: 10, bottom: true } }

      it 'does not add bottom match line' do
        line = subject.diff_lines.last

        expect(line.type).to be_nil
      end
    end
  end

  describe '#lines' do
    context 'when scope is specified' do
      let(:params) { { since: 2, to: 3 } }

      it 'returns lines cropped by params' do
        expect(subject.lines.size).to eq(2)
        expect(subject.lines[0]).to include('LC2')
        expect(subject.lines[1]).to include('LC3')
      end
    end

    context 'when full is true' do
      let(:params) { { full: true } }

      it 'returns all lines' do
        expect(subject.lines.size).to eq(3)
        expect(subject.lines[0]).to include('LC1')
        expect(subject.lines[1]).to include('LC2')
        expect(subject.lines[2]).to include('LC3')
      end
    end
  end

  describe '#match_line_text' do
    context 'when bottom is true' do
      let(:params) { { since: 2, to: 3, bottom: true } }

      it 'returns empty string' do
        expect(subject.match_line_text).to eq('')
      end
    end

    context 'when bottom is false' do
      let(:params) { { since: 2, to: 3, bottom: false } }

      it 'returns match line string' do
        expect(subject.match_line_text).to eq("@@ -2,1+2,1 @@")
      end
    end
  end
end
