# frozen_string_literal: true

require 'spec_helper'
require 'haml_lint'
require 'haml_lint/spec'
require Rails.root.join('haml_lint/linter/documentation_links')

RSpec.describe HamlLint::Linter::DocumentationLinks do
  include_context 'linter'

  context 'when link_to points to the existing file path' do
    let(:haml) { "= link_to 'Description', help_page_path('README.md')" }

    it { is_expected.not_to report_lint }
  end

  context 'when link_to points to the existing file with valid anchor' do
    let(:haml) { "= link_to 'Description', help_page_path('README.md', anchor: 'overview'), target: '_blank'" }

    it { is_expected.not_to report_lint }
  end

  context 'when link_to points to the existing file path without .md extension' do
    let(:haml) { "= link_to 'Description', help_page_path('README')" }

    it { is_expected.not_to report_lint }
  end

  context 'when anchor is not correct' do
    let(:haml) { "= link_to 'Description', help_page_path('README.md', anchor: 'wrong')" }

    it { is_expected.to report_lint }

    context 'when help_page_path has multiple options' do
      let(:haml) { "= link_to 'Description', help_page_path('README.md', key: :value, anchor: 'wrong')" }

      it { is_expected.to report_lint }
    end
  end

  context 'when file path is wrong' do
    let(:haml) { "= link_to 'Description', help_page_path('wrong.md'), target: '_blank'" }

    it { is_expected.to report_lint }
  end

  context 'when link with wrong file path is assigned to a variable' do
    let(:haml) { "- my_link = link_to 'Description', help_page_path('wrong.md')" }

    it { is_expected.to report_lint }
  end

  context 'when it is a broken code' do
    let(:haml) { "= I am broken! ]]]]" }

    it { is_expected.not_to report_lint }
  end

  context 'when anchor belongs to a different element' do
    let(:haml) { "= link_to 'Description', help_page_path('README.md'), target: (anchor: 'blank')" }

    it { is_expected.not_to report_lint }
  end

  context 'when a simple help_page_path' do
    let(:haml) { "- url = help_page_path('wrong.md')" }

    it { is_expected.to report_lint }
  end

  context 'when link is not a string' do
    let(:haml) { "- url = help_page_path(help_url)" }

    it { is_expected.not_to report_lint }
  end

  context 'when link is a part of the tag' do
    let(:haml) { ".data-form{ data: { url: help_page_path('wrong.md') } }" }

    it { is_expected.to report_lint }
  end
end
