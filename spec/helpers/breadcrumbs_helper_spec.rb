# frozen_string_literal: true

require 'spec_helper'

RSpec.describe BreadcrumbsHelper do
  describe '#push_to_schema_breadcrumb' do
    it 'enqueue element name, link and position' do
      element = ['element1', 'link1']
      helper.push_to_schema_breadcrumb(element[0], element[1])

      list = helper.instance_variable_get(:@schema_breadcrumb_list)

      aggregate_failures do
        expect(list[0]['name']).to eq element[0]
        expect(list[0]['item']).to eq element[1]
        expect(list[0]['position']).to eq(1)

      end
    end
  end

  describe '#schema_breadcrumb_json' do
    let(:elements) do
      [
        ['element1', 'link1'],
        ['element2', 'link2']
      ]
    end

    subject { helper.schema_breadcrumb_json }

    it 'returns the breadcrumb schema in json format' do
      enqueue_breadcrumb_elements

      expected_result = {
        '@context' => 'https://schema.org',
        '@type' => 'BreadcrumbList',
        'itemListElement' => [
          {
            '@type' => 'ListItem',
            'position' => 1,
            'name' => elements[0][0],
            'item' => elements[0][1]
          },
          {
            '@type' => 'ListItem',
            'position' => 2,
            'name' => elements[1][0],
            'item' => elements[1][1]
          }
        ]
      }.to_json

      expect(subject).to eq expected_result
    end

    context 'when extra breadcrum element is added' do
      let(:extra_elements) do
        [
          ['extra_element1', 'extra_link1'],
          ['extra_element2', 'extra_link2']
        ]
      end

      it 'include the extra elements before the last element' do
        enqueue_breadcrumb_elements

        extra_elements.each do |el|
          add_to_breadcrumbs(el[0], el[1])
        end

        expected_result = {
        '@context' => 'https://schema.org',
        '@type' => 'BreadcrumbList',
        'itemListElement' => [
          {
            '@type' => 'ListItem',
            'position' => 1,
            'name' => elements[0][0],
            'item' => elements[0][1]
          },
          {
            '@type' => 'ListItem',
            'position' => 2,
            'name' => extra_elements[0][0],
            'item' => extra_elements[0][1]
          },
          {
            '@type' => 'ListItem',
            'position' => 3,
            'name' => extra_elements[1][0],
            'item' => extra_elements[1][1]
          },
          {
            '@type' => 'ListItem',
            'position' => 4,
            'name' => elements[1][0],
            'item' => elements[1][1]
          }
        ]}.to_json

        expect(subject).to eq expected_result
      end
    end

    def enqueue_breadcrumb_elements
      elements.each do |el|
        helper.push_to_schema_breadcrumb(el[0], el[1])
      end
    end
  end
end
