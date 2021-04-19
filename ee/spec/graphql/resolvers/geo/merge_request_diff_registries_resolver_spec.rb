# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Geo::MergeRequestDiffRegistriesResolver, let_it_be_light_freeze: false do
  it_behaves_like 'a Geo registries resolver', :geo_merge_request_diff_registry
end
