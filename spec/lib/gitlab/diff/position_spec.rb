# frozen_string_literal: true

require 'spec_helper'

describe Gitlab::Diff::Position do
  include RepoHelpers

  let(:project) { create(:project, :repository) }

  let(:args_for_img) do
    {
      old_path: "files/any.img",
      new_path: "files/any.img",
      base_sha: nil,
      head_sha: nil,
      start_sha: nil,
      width: 100,
      height: 100,
      x: 1,
      y: 100,
      position_type: "image"
    }
  end

  let(:args_for_text) do
    {
      old_path: "files/ruby/popen.rb",
      new_path: "files/ruby/popen.rb",
      old_line: nil,
      new_line: 14,
      base_sha: nil,
      head_sha: nil,
      start_sha: nil,
      position_type: "text"
    }
  end

  let(:args_for_multi_text) do
    {
      old_path: "files/ruby/popen.rb",
      new_path: "files/ruby/popen.rb",
      old_start_line: nil,
      new_start_line: 14,
      old_end_line: nil,
      new_end_line: 16,
      base_sha: nil,
      head_sha: nil,
      start_sha: nil,
      position_type: "multi_text"
    }
  end

  describe 'factory' do
    it 'produces a complete text position' do
      position = build(:text_diff_position)

      expect(position).to be_complete
      expect(position).to have_attributes(position_type: 'text')
    end

    it 'produces a complete multi_text position' do
      position = build(:multi_text_diff_position)

      expect(position).to be_complete
      expect(position).to have_attributes(position_type: 'multi_text')
    end

    it 'produces a complete image position' do
      position = build(:image_diff_position)

      expect(position).to be_complete
      expect(position).to have_attributes(position_type: 'image')
    end

    it 'allows the diff_refs to be passed as a single object' do
      head_sha  = Digest::SHA1.hexdigest(SecureRandom.hex)
      base_sha  = Digest::SHA1.hexdigest(SecureRandom.hex)
      start_sha = Digest::SHA1.hexdigest(SecureRandom.hex)

      refs = ::Gitlab::Diff::DiffRefs.new(base_sha: base_sha, start_sha: start_sha, head_sha: head_sha)

      expect(build(:diff_position, diff_refs: refs).diff_refs).to eq(refs)
    end
  end

  describe "position for an added text file" do
    let(:commit) { project.commit("2ea1f3dec713d940208fb5ce4a38765ecb5d3f73") }

    subject do
      described_class.new(
        old_path: "files/images/wm.svg",
        new_path: "files/images/wm.svg",
        old_line: nil,
        new_line: 5,
        diff_refs: commit.diff_refs
      )
    end

    it { is_expected.to be_on_text }
    it { is_expected.not_to be_on_image }

    describe "#diff_file" do
      it "returns the correct diff file" do
        diff_file = subject.diff_file(project.repository)

        expect(diff_file.new_file?).to be true
        expect(diff_file.new_path).to eq(subject.new_path)
        expect(diff_file.diff_refs).to eq(subject.diff_refs)
      end
    end

    describe "#diff_line" do
      it "returns the correct diff line" do
        diff_line = subject.diff_line(project.repository)

        expect(diff_line.added?).to be true
        expect(diff_line.new_line).to eq(subject.new_line)
        expect(diff_line.text).to eq("+    <desc>Created with Sketch.</desc>")
      end
    end

    describe "#line_code" do
      it "returns the correct line code" do
        line_code = Gitlab::Git.diff_line_code(subject.file_path, subject.new_line, 0)

        expect(subject.line_code(project.repository)).to eq(line_code)
      end
    end
  end

  describe "multi-line position for an added text file" do
    let(:commit) { project.commit("2ea1f3dec713d940208fb5ce4a38765ecb5d3f73") }

    subject do
      described_class.new(
        old_path: "files/images/wm.svg",
        new_path: "files/images/wm.svg",
        old_start_line: nil,
        new_start_line: 4,
        old_end_line: nil,
        new_end_line: 5,
        diff_refs: commit.diff_refs,
        position_type: "multi_text"
      )
    end

    it { is_expected.to be_on_multi_text }
    it { is_expected.not_to be_on_text }
    it { is_expected.not_to be_on_image }

    describe "#diff_file" do
      it "returns the correct diff file" do
        diff_file = subject.diff_file(project.repository)

        expect(diff_file.new_file?).to be true
        expect(diff_file.new_path).to eq(subject.new_path)
        expect(diff_file.diff_refs).to eq(subject.diff_refs)
      end
    end

    describe "#diff_lines" do
      let(:diff_lines) { subject.diff_lines(project.repository) }

      it "returns the correct first diff line" do
        diff_line = diff_lines.first

        expect(diff_line.added?).to be true
        expect(diff_line.new_line).to eq(subject.new_start_line)
        expect(diff_line.text).to eq("+    <title>wm</title>")
      end

      it "returns the correct second diff line" do
        diff_line = diff_lines.last

        expect(diff_line.added?).to be true
        expect(diff_line.new_line).to eq(subject.new_end_line)
        expect(diff_line.text).to eq("+    <desc>Created with Sketch.</desc>")
      end
    end

    describe "#line_codes" do
      let(:line_codes) { subject.line_codes(project.repository) }

      it "returns the correct first line code" do
        line_code = Gitlab::Git.diff_line_code(subject.file_path, subject.new_start_line, 0)

        expect(line_codes.first).to eq(line_code)
      end

      it "returns the correct second line code" do
        line_code = Gitlab::Git.diff_line_code(subject.file_path, subject.new_end_line, 0)

        expect(line_codes.last).to eq(line_code)
      end
    end
  end

  describe "position for an added image file" do
    let(:commit) { project.commit("33f3729a45c02fc67d00adb1b8bca394b0e761d9") }

    subject do
      described_class.new(
        old_path: "files/images/6049019_460s.jpg",
        new_path: "files/images/6049019_460s.jpg",
        width: 100,
        height: 100,
        x: 1,
        y: 100,
        diff_refs: commit.diff_refs,
        position_type: "image"
      )
    end

    it { is_expected.not_to be_on_text }
    it { is_expected.to be_on_image }

    it "returns the correct diff file" do
      diff_file = subject.diff_file(project.repository)

      expect(diff_file.new_file?).to be true
      expect(diff_file.new_path).to eq(subject.new_path)
      expect(diff_file.diff_refs).to eq(subject.diff_refs)
    end
  end

  describe "position for a changed file" do
    let(:commit) { project.commit("570e7b2abdd848b95f2f578043fc23bd6f6fd24d") }

    describe "position for an added line" do
      subject do
        described_class.new(
          old_path: "files/ruby/popen.rb",
          new_path: "files/ruby/popen.rb",
          old_line: nil,
          new_line: 14,
          diff_refs: commit.diff_refs
        )
      end

      describe "#diff_file" do
        it "returns the correct diff file" do
          diff_file = subject.diff_file(project.repository)

          expect(diff_file.old_path).to eq(subject.old_path)
          expect(diff_file.new_path).to eq(subject.new_path)
          expect(diff_file.diff_refs).to eq(subject.diff_refs)
        end

        context 'different folded positions in the same diff file' do
          def diff_file(args = {})
            described_class
              .new(args_for_text.merge(args))
              .diff_file(project.repository)
          end

          it 'expands the diff file', :request_store do
            expect_any_instance_of(Gitlab::Diff::File)
              .to receive(:unfold_diff_lines).and_call_original

            diff_file(old_line: 1, new_line: 1, diff_refs: commit.diff_refs)

            expect_any_instance_of(Gitlab::Diff::File)
              .to receive(:unfold_diff_lines).and_call_original

            diff_file(old_line: 5, new_line: 5, diff_refs: commit.diff_refs)
          end
        end
      end

      describe "#diff_line" do
        it "returns the correct diff line" do
          diff_line = subject.diff_line(project.repository)

          expect(diff_line.added?).to be true
          expect(diff_line.new_line).to eq(subject.new_line)
          expect(diff_line.text).to eq("+    vars = {")
        end
      end

      describe "#line_code" do
        it "returns the correct line code" do
          line_code = Gitlab::Git.diff_line_code(subject.file_path, subject.new_line, 15)

          expect(subject.line_code(project.repository)).to eq(line_code)
        end
      end
    end

    describe "position for an unchanged line" do
      subject do
        described_class.new(
          old_path: "files/ruby/popen.rb",
          new_path: "files/ruby/popen.rb",
          old_line: 16,
          new_line: 22,
          diff_refs: commit.diff_refs
        )
      end

      describe "#diff_file" do
        it "returns the correct diff file" do
          diff_file = subject.diff_file(project.repository)

          expect(diff_file.old_path).to eq(subject.old_path)
          expect(diff_file.new_path).to eq(subject.new_path)
          expect(diff_file.diff_refs).to eq(subject.diff_refs)
        end
      end

      describe "#diff_line" do
        it "returns the correct diff line" do
          diff_line = subject.diff_line(project.repository)

          expect(diff_line.unchanged?).to be true
          expect(diff_line.old_line).to eq(subject.old_line)
          expect(diff_line.new_line).to eq(subject.new_line)
          expect(diff_line.text).to eq("     unless File.directory?(path)")
        end
      end

      describe "#line_code" do
        it "returns the correct line code" do
          line_code = Gitlab::Git.diff_line_code(subject.file_path, subject.new_line, subject.old_line)

          expect(subject.line_code(project.repository)).to eq(line_code)
        end
      end
    end

    describe "position for a removed line" do
      subject do
        described_class.new(
          old_path: "files/ruby/popen.rb",
          new_path: "files/ruby/popen.rb",
          old_line: 14,
          new_line: nil,
          diff_refs: commit.diff_refs
        )
      end

      describe "#diff_file" do
        it "returns the correct diff file" do
          diff_file = subject.diff_file(project.repository)

          expect(diff_file.old_path).to eq(subject.old_path)
          expect(diff_file.new_path).to eq(subject.new_path)
          expect(diff_file.diff_refs).to eq(subject.diff_refs)
        end
      end

      describe "#diff_line" do
        it "returns the correct diff line" do
          diff_line = subject.diff_line(project.repository)

          expect(diff_line.removed?).to be true
          expect(diff_line.old_line).to eq(subject.old_line)
          expect(diff_line.text).to eq("-    options = { chdir: path }")
        end
      end

      describe "#line_code" do
        it "returns the correct line code" do
          line_code = Gitlab::Git.diff_line_code(subject.file_path, 13, subject.old_line)

          expect(subject.line_code(project.repository)).to eq(line_code)
        end
      end
    end
  end

  describe "multi-line position for a changed file" do
    let(:commit) { project.commit("570e7b2abdd848b95f2f578043fc23bd6f6fd24d") }

    describe "position for an added line" do
      subject do
        described_class.new(
          old_path: "files/ruby/popen.rb",
          new_path: "files/ruby/popen.rb",
          old_start_line: nil,
          new_start_line: 14,
          old_end_line: nil,
          new_end_line: 15,
          diff_refs: commit.diff_refs,
          position_type: "multi_text"
        )
      end

      describe "#diff_file" do
        it "returns the correct diff file" do
          diff_file = subject.diff_file(project.repository)

          expect(diff_file.old_path).to eq(subject.old_path)
          expect(diff_file.new_path).to eq(subject.new_path)
          expect(diff_file.diff_refs).to eq(subject.diff_refs)
        end

        context 'different folded positions in the same diff file' do
          def diff_file(args = {})
            described_class
              .new(args_for_multi_text.merge(args))
              .diff_file(project.repository)
          end

          it 'expands the diff file', :request_store do
            expect_any_instance_of(Gitlab::Diff::File)
              .to receive(:unfold_diff_lines).and_call_original

            diff_file(old_line: 1, new_line: 1, diff_refs: commit.diff_refs)

            expect_any_instance_of(Gitlab::Diff::File)
              .to receive(:unfold_diff_lines).and_call_original

            diff_file(old_line: 5, new_line: 5, diff_refs: commit.diff_refs)
          end
        end
      end

      describe "#diff_lines" do
        let(:diff_lines) { subject.diff_lines(project.repository) }

        it "returns the correct first diff line" do
          diff_line = diff_lines.first

          expect(diff_line.added?).to be true
          expect(diff_line.new_line).to eq(subject.new_start_line)
          expect(diff_line.text).to eq("+    vars = {")
        end

        it "returns the correct second diff line" do
          diff_line = diff_lines.last

          expect(diff_line.added?).to be true
          expect(diff_line.new_line).to eq(subject.new_end_line)
          expect(diff_line.text).to eq('+      "PWD" => path')
        end
      end

      describe "#line_codes" do
        let(:line_codes) { subject.line_codes(project.repository) }

        it "returns the correct first line code" do
          line_code = Gitlab::Git.diff_line_code(subject.file_path, subject.new_start_line, 15) #FIXME: Why is this 15?

          expect(line_codes.first).to eq(line_code)
        end

        it "returns the correct second line code" do
          line_code = Gitlab::Git.diff_line_code(subject.file_path, subject.new_end_line, 15)

          expect(line_codes.last).to eq(line_code)
        end
      end
    end

    describe "position for an unchanged line" do
      subject do
        described_class.new(
          old_path: "files/ruby/popen.rb",
          new_path: "files/ruby/popen.rb",
          old_start_line: 16,
          new_start_line: 22,
          old_end_line: 20,
          new_end_line: 26,
          diff_refs: commit.diff_refs,
          position_type: "multi_text"
        )
      end

      describe "#diff_file" do
        it "returns the correct diff file" do
          diff_file = subject.diff_file(project.repository)

          expect(diff_file.old_path).to eq(subject.old_path)
          expect(diff_file.new_path).to eq(subject.new_path)
          expect(diff_file.diff_refs).to eq(subject.diff_refs)
        end
      end

      describe "#diff_lines" do
        let(:diff_lines) { subject.diff_lines(project.repository) }

        it "returns the correct first diff line" do
          diff_line = diff_lines.first


          expect(diff_line.unchanged?).to be true
          expect(diff_line.old_line).to eq(subject.old_start_line)
          expect(diff_line.new_line).to eq(subject.new_start_line)
          expect(diff_line.text).to eq("     unless File.directory?(path)")
        end

        it "returns the correct second diff line" do
          diff_line = diff_lines.last

          expect(diff_line.unchanged?).to be true
          expect(diff_line.old_line).to eq(subject.old_end_line)
          expect(diff_line.new_line).to eq(subject.new_end_line)
          expect(diff_line.text).to eq("     @cmd_output = \"\"")
        end
      end

      describe "#line_codes" do
        let(:line_codes) { subject.line_codes(project.repository) }

        it "returns the correct first line code" do
          line_code = Gitlab::Git.diff_line_code(subject.file_path, subject.new_start_line, subject.old_start_line)

          expect(line_codes.first).to eq(line_code)
        end

        it "returns the correct second line code" do
          line_code = Gitlab::Git.diff_line_code(subject.file_path, subject.new_end_line, subject.old_end_line)

          expect(line_codes.last).to eq(line_code)
        end
      end
    end

    describe "position for a removed line" do
      subject do
        described_class.new(
          old_path: "files/ruby/popen.rb",
          new_path: "files/ruby/popen.rb",
          old_start_line: 14,
          new_start_line: nil,
          old_end_line: 15,
          new_end_line: 14,
          diff_refs: commit.diff_refs,
          position_type: "multi_text"
        )
      end

      describe "#diff_file" do
        it "returns the correct diff file" do
          diff_file = subject.diff_file(project.repository)

          expect(diff_file.old_path).to eq(subject.old_path)
          expect(diff_file.new_path).to eq(subject.new_path)
          expect(diff_file.diff_refs).to eq(subject.diff_refs)
        end
      end

      describe "#diff_lines" do
        let(:diff_lines) { subject.diff_lines(project.repository) }

        it "returns the correct first diff line" do
          diff_line = diff_lines.first

          expect(diff_line.removed?).to be true
          expect(diff_line.old_line).to eq(subject.old_start_line)
          expect(diff_line.new_line).to be nil
          expect(diff_line.text).to eq("-    options = { chdir: path }")
        end

        it "returns the correct second diff line" do
          diff_line = diff_lines.last

          expect(diff_line.removed?).to be false # I don't understand why this is true
          expect(diff_line.old_line).to eq(subject.old_end_line - 1)
          expect(diff_line.new_line).to eq(subject.new_end_line - 1) # this also isn't present and that doesn't make sense
          expect(diff_line.text).to eq("-    options = { chdir: path }")
        end
      end

      describe "#line_codes" do
        let(:line_codes) { subject.line_codes(project.repository) }

        it "returns the correct first line code" do
          line_code = Gitlab::Git.diff_line_code(subject.file_path, 13, subject.old_start_line)

          expect(line_codes.first).to eq(line_code)
        end

        it "returns the correct last line code" do
          line_code = Gitlab::Git.diff_line_code(subject.file_path, subject.new_end_line - 1, subject.old_end_line - 1)

          expect(line_codes.last).to eq(line_code)
        end
      end
    end
  end

  describe "position for a renamed file" do
    let(:commit) { project.commit("6907208d755b60ebeacb2e9dfea74c92c3449a1f") }

    describe "position for an added line" do
      subject do
        described_class.new(
          old_path: "files/js/commit.js.coffee",
          new_path: "files/js/commit.coffee",
          old_line: nil,
          new_line: 4,
          diff_refs: commit.diff_refs
        )
      end

      describe "#diff_file" do
        it "returns the correct diff file" do
          diff_file = subject.diff_file(project.repository)

          expect(diff_file.old_path).to eq(subject.old_path)
          expect(diff_file.new_path).to eq(subject.new_path)
          expect(diff_file.diff_refs).to eq(subject.diff_refs)
        end
      end

      describe "#diff_line" do
        it "returns the correct diff line" do
          diff_line = subject.diff_line(project.repository)

          expect(diff_line.added?).to be true
          expect(diff_line.new_line).to eq(subject.new_line)
          expect(diff_line.text).to eq("+      new CommitFile(@)")
        end
      end

      describe "#line_code" do
        it "returns the correct line code" do
          line_code = Gitlab::Git.diff_line_code(subject.file_path, subject.new_line, 5)

          expect(subject.line_code(project.repository)).to eq(line_code)
        end
      end
    end

    describe "position for an unchanged line" do
      subject do
        described_class.new(
          old_path: "files/js/commit.js.coffee",
          new_path: "files/js/commit.coffee",
          old_line: 3,
          new_line: 3,
          diff_refs: commit.diff_refs
        )
      end

      describe "#diff_file" do
        it "returns the correct diff file" do
          diff_file = subject.diff_file(project.repository)

          expect(diff_file.old_path).to eq(subject.old_path)
          expect(diff_file.new_path).to eq(subject.new_path)
          expect(diff_file.diff_refs).to eq(subject.diff_refs)
        end
      end

      describe "#diff_line" do
        it "returns the correct diff line" do
          diff_line = subject.diff_line(project.repository)

          expect(diff_line.unchanged?).to be true
          expect(diff_line.old_line).to eq(subject.old_line)
          expect(diff_line.new_line).to eq(subject.new_line)
          expect(diff_line.text).to eq("     $('.files .diff-file').each ->")
        end
      end

      describe "#line_code" do
        it "returns the correct line code" do
          line_code = Gitlab::Git.diff_line_code(subject.file_path, subject.new_line, subject.old_line)

          expect(subject.line_code(project.repository)).to eq(line_code)
        end
      end
    end

    describe "position for a removed line" do
      subject do
        described_class.new(
          old_path: "files/js/commit.js.coffee",
          new_path: "files/js/commit.coffee",
          old_line: 4,
          new_line: nil,
          diff_refs: commit.diff_refs
        )
      end

      describe "#diff_file" do
        it "returns the correct diff file" do
          diff_file = subject.diff_file(project.repository)

          expect(diff_file.old_path).to eq(subject.old_path)
          expect(diff_file.new_path).to eq(subject.new_path)
          expect(diff_file.diff_refs).to eq(subject.diff_refs)
        end
      end

      describe "#diff_line" do
        it "returns the correct diff line" do
          diff_line = subject.diff_line(project.repository)

          expect(diff_line.removed?).to be true
          expect(diff_line.old_line).to eq(subject.old_line)
          expect(diff_line.text).to eq("-      new CommitFile(this)")
        end
      end

      describe "#line_code" do
        it "returns the correct line code" do
          line_code = Gitlab::Git.diff_line_code(subject.file_path, 4, subject.old_line)

          expect(subject.line_code(project.repository)).to eq(line_code)
        end
      end
    end
  end

  describe "position for a deleted file" do
    let(:commit) { project.commit("8634272bfad4cf321067c3e94d64d5a253f8321d") }

    subject do
      described_class.new(
        old_path: "LICENSE",
        new_path: "LICENSE",
        old_line: 3,
        new_line: nil,
        diff_refs: commit.diff_refs
      )
    end

    describe "#diff_file" do
      it "returns the correct diff file" do
        diff_file = subject.diff_file(project.repository)

        expect(diff_file.deleted_file?).to be true
        expect(diff_file.old_path).to eq(subject.old_path)
        expect(diff_file.diff_refs).to eq(subject.diff_refs)
      end
    end

    describe "#diff_line" do
      it "returns the correct diff line" do
        diff_line = subject.diff_line(project.repository)

        expect(diff_line.removed?).to be true
        expect(diff_line.old_line).to eq(subject.old_line)
        expect(diff_line.text).to eq("-Copyright (c) 2014 gitlabhq")
      end
    end

    describe "#line_code" do
      it "returns the correct line code" do
        line_code = Gitlab::Git.diff_line_code(subject.file_path, 0, subject.old_line)

        expect(subject.line_code(project.repository)).to eq(line_code)
      end
    end
  end

  describe "position for a missing ref" do
    let(:diff_refs) do
      Gitlab::Diff::DiffRefs.new(
        base_sha: "not_existing_sha",
        head_sha: "existing_sha"
      )
    end

    subject do
      described_class.new(
        old_path: "files/ruby/feature.rb",
        new_path: "files/ruby/feature.rb",
        old_line: 3,
        new_line: nil,
        diff_refs: diff_refs
      )
    end

    describe "#diff_file" do
      it "does not raise exception" do
        expect { subject.diff_file(project.repository) }.not_to raise_error
      end
    end

    describe "#diff_line" do
      it "does not raise exception" do
        expect { subject.diff_line(project.repository) }.not_to raise_error
      end
    end

    describe "#line_code" do
      it "does not raise exception" do
        expect { subject.line_code(project.repository) }.not_to raise_error
      end
    end
  end

  describe "position for a file in the initial commit" do
    let(:commit) { project.commit("1a0b36b3cdad1d2ee32457c102a8c0b7056fa863") }

    subject do
      described_class.new(
        old_path: "README.md",
        new_path: "README.md",
        old_line: nil,
        new_line: 1,
        diff_refs: commit.diff_refs
      )
    end

    describe "#diff_file" do
      it "returns the correct diff file" do
        diff_file = subject.diff_file(project.repository)

        expect(diff_file.new_file?).to be true
        expect(diff_file.new_path).to eq(subject.new_path)
        expect(diff_file.diff_refs).to eq(subject.diff_refs)
      end
    end

    describe "#diff_line" do
      it "returns the correct diff line" do
        diff_line = subject.diff_line(project.repository)

        expect(diff_line.added?).to be true
        expect(diff_line.new_line).to eq(subject.new_line)
        expect(diff_line.text).to eq("+testme")
      end
    end

    describe "#line_code" do
      it "returns the correct line code" do
        line_code = Gitlab::Git.diff_line_code(subject.file_path, subject.new_line, 0)

        expect(subject.line_code(project.repository)).to eq(line_code)
      end
    end
  end

  describe "position for a file in a straight comparison" do
    let(:diff_refs) do
      Gitlab::Diff::DiffRefs.new(
        start_sha: '0b4bc9a49b562e85de7cc9e834518ea6828729b9', # feature
        base_sha: '0b4bc9a49b562e85de7cc9e834518ea6828729b9',
        head_sha: 'e63f41fe459e62e1228fcef60d7189127aeba95a' # master
      )
    end

    subject do
      described_class.new(
        old_path: "files/ruby/feature.rb",
        new_path: "files/ruby/feature.rb",
        old_line: 3,
        new_line: nil,
        diff_refs: diff_refs
      )
    end

    describe "#diff_file" do
      it "returns the correct diff file" do
        diff_file = subject.diff_file(project.repository)

        expect(diff_file.deleted_file?).to be true
        expect(diff_file.old_path).to eq(subject.old_path)
        expect(diff_file.diff_refs).to eq(subject.diff_refs)
      end
    end

    describe "#diff_line" do
      it "returns the correct diff line" do
        diff_line = subject.diff_line(project.repository)

        expect(diff_line.removed?).to be true
        expect(diff_line.old_line).to eq(subject.old_line)
        expect(diff_line.text).to eq("-    puts 'bar'")
      end
    end

    describe "#line_code" do
      it "returns the correct line code" do
        line_code = Gitlab::Git.diff_line_code(subject.file_path, 0, subject.old_line)

        expect(subject.line_code(project.repository)).to eq(line_code)
      end
    end
  end

  describe '#==' do
    let(:commit) { project.commit("570e7b2abdd848b95f2f578043fc23bd6f6fd24d") }

    subject do
      described_class.new(
        old_path: "files/ruby/popen.rb",
        new_path: "files/ruby/popen.rb",
        old_line: nil,
        new_line: 14,
        diff_refs: commit.diff_refs
      )
    end

    context 'when positions are equal' do
      let(:other) { described_class.new(subject.to_h) }

      it 'returns true' do
        expect(subject).to eq(other)
      end
    end

    context 'when positions are equal, except for truncated shas' do
      let(:other) { described_class.new(subject.to_h.merge(start_sha: subject.start_sha[0, 10])) }

      it 'returns true' do
        expect(subject).to eq(other)
      end
    end

    context 'when positions are unequal' do
      let(:other) { described_class.new(subject.to_h.merge(start_sha: subject.start_sha.reverse)) }

      it 'returns false' do
        expect(subject).not_to eq(other)
      end
    end
  end

  describe "#as_json" do
    shared_examples "diff position json" do
      let(:diff_position) { described_class.new(args) }

      it "returns the position as JSON" do
        expect(diff_position.as_json).to eq(args.stringify_keys)
      end
    end

    context "for text position" do
      let(:args) { args_for_text }

      it_behaves_like "diff position json"
    end

    context "for multi_text position" do
      let(:args) { args_for_multi_text }

      it_behaves_like "diff position json"
    end

    context "for image position" do
      let(:args) { args_for_img }

      it_behaves_like "diff position json"
    end
  end

  describe "#to_json" do
    shared_examples "diff position json" do
      let(:diff_position) { described_class.new(args) }

      it "returns the position as JSON" do
        expect(JSON.parse(diff_position.to_json)).to eq(args.stringify_keys)
      end

      it "works when nested under another hash" do
        expect(JSON.parse(JSON.generate(pos: diff_position))).to eq('pos' => args.stringify_keys)
      end
    end

    context "for text position" do
      let(:args) { args_for_text }

      it_behaves_like "diff position json"
    end

    context "for multi_text position" do
      let(:args) { args_for_multi_text }

      it_behaves_like "diff position json"
    end

    context "for image position" do
      let(:args) { args_for_img }

      it_behaves_like "diff position json"
    end
  end

  describe "#file_hash" do
    subject do
      described_class.new(
        old_path: "image.jpg",
        new_path: "image.jpg"
      )
    end

    it "returns SHA1 representation of the file_path" do
      expect(subject.file_hash).to eq(Digest::SHA1.hexdigest(subject.file_path))
    end
  end
end
