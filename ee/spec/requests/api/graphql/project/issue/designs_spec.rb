# frozen_string_literal: true

require 'spec_helper'

describe "Getting designs related to an issue" do
  include GraphqlHelpers

  set(:design) { create(:design, :with_file, versions_count: 1) }
  set(:current_user) { design.project.owner }

  let(:query) do
    design_node = <<~NODE
    designs {
      edges {
        node {
          filename
          image
          versions {
            edges {
              node {
                image
                sha
              }
            }
          }
        }
      }
    }
    NODE
    graphql_query_for(
      "project",
      { "fullPath" => design.project.full_path },
      query_graphql_field(
        "issue",
        { iid: design.issue.iid },
        query_graphql_field(
          "designs", {}, design_node
        )
      )
    )
  end
  let(:design_collection) do
    graphql_data["project"]["issue"]["designs"]
  end
  let(:design_response) do
    design_collection["designs"]["edges"].first["node"]
  end

  context "when the feature is not available" do
    before do
      stub_licensed_features(design_management: false)
      stub_feature_flags(design_managment: false)
    end

    it_behaves_like "a working graphql query" do
      before do
        post_graphql(query, current_user: current_user)
      end
    end

    it "returns no designs" do
      post_graphql(query, current_user: current_user)

      expect(design_collection).to be_nil
    end
  end

  context "when the feature is available" do
    before do
      stub_licensed_features(design_management: true)
      stub_feature_flags(deesign_managment: true)
    end

    it "returns the design filename" do
      post_graphql(query, current_user: current_user)

      expect(design_response["filename"]).to eq(design.filename)
    end

    it "returns the path to the design image" do
      post_graphql(query, current_user: current_user)

      expect(design_response["image"]).to eq(
        Gitlab::Routing.url_helpers.project_design_url(design.project, design)
      )
    end

    describe "design versions" do
      let(:version) { design.versions.take }

      it "includes the version sha" do
        post_graphql(query, current_user: current_user)

        version_sha = design_response["versions"]["edges"].first["node"]["sha"]

        expect(version_sha).to eq(version.sha)
      end

      it "includes the path to the version image" do
        post_graphql(query, current_user: current_user)

        version_image = design_response["versions"]["edges"].first["node"]["image"]

        expect(version_image).to eq(
          Gitlab::Routing.url_helpers.project_design_url(design.project, design, ref: version.sha)
        )
      end
    end
  end
end
