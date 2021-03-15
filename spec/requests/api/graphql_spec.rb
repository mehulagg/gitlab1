# frozen_string_literal: true
require 'spec_helper'

RSpec.describe 'GraphQL' do
  include GraphqlHelpers

  let(:query) { graphql_query_for('echo', text: 'Hello world' ) }

  context 'logging' do
    shared_examples 'logging a graphql query' do
      let(:expected_params) do
        {
          query_string: query,
          variables: variables.to_s,
          duration_s: anything,
          depth: 1,
          complexity: 1,
          used_fields: ['Query.echo'],
          used_deprecated_fields: []
        }
      end

      it 'logs a query with the expected params' do
        expect(Gitlab::GraphqlLogger).to receive(:info).with(expected_params).once

        post_graphql(query, variables: variables)
      end

      it 'does not instantiate any query analyzers' do # they are static and re-used
        expect(GraphQL::Analysis::QueryComplexity).not_to receive(:new)
        expect(GraphQL::Analysis::QueryDepth).not_to receive(:new)

        2.times { post_graphql(query, variables: variables) }
      end
    end

    context 'with no variables' do
      let(:variables) { {} }

      it_behaves_like 'logging a graphql query'
    end

    context 'with variables' do
      let(:variables) do
        { "foo" => "bar" }
      end

      it_behaves_like 'logging a graphql query'
    end

    context 'when there is an error in the logger' do
      before do
        allow_any_instance_of(Gitlab::Graphql::QueryAnalyzers::LoggerAnalyzer).to receive(:process_variables).and_raise(StandardError.new("oh noes!"))
      end

      it 'logs the exception in Sentry and continues with the request' do
        expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception).at_least(:once)
        expect(Gitlab::GraphqlLogger).to receive(:info)

        post_graphql(query, variables: {})
      end
    end
  end

  context 'invalid variables' do
    it 'returns an error' do
      post_graphql(query, variables: "This is not JSON")

      expect(response).to have_gitlab_http_status(:unprocessable_entity)
      expect(json_response['errors'].first['message']).not_to be_nil
    end
  end

  context 'authentication', :allow_forgery_protection do
    let(:user) { create(:user) }

    it 'allows access to public data without authentication' do
      post_graphql(query)

      expect(graphql_data['echo']).to eq('nil says: Hello world')
    end

    it 'does not authenticate a user with an invalid CSRF' do
      login_as(user)

      post_graphql(query, headers: { 'X-CSRF-Token' => 'invalid' })

      expect(graphql_data['echo']).to eq('nil says: Hello world')
    end

    it 'authenticates a user with a valid session token' do
      # Create a session to get a CSRF token from
      login_as(user)
      get('/')

      post '/api/graphql', params: { query: query }, headers: { 'X-CSRF-Token' => response.session['_csrf_token'] }

      expect(graphql_data['echo']).to eq("\"#{user.username}\" says: Hello world")
    end

    context 'token authentication' do
      let(:token) { create(:personal_access_token) }

      before do
        stub_authentication_activity_metrics(debug: false)
      end

      it 'authenticates users with a PAT' do
        expect(authentication_metrics)
          .to increment(:user_authenticated_counter)
          .and increment(:user_session_override_counter)
          .and increment(:user_sessionless_authentication_counter)

        post_graphql(query, headers: { 'PRIVATE-TOKEN' => token.token })

        expect(graphql_data['echo']).to eq("\"#{token.user.username}\" says: Hello world")
      end

      context 'when the personal access token has no api scope' do
        it 'does not log the user in' do
          token.update(scopes: [:read_user])

          post_graphql(query, headers: { 'PRIVATE-TOKEN' => token.token })

          expect(response).to have_gitlab_http_status(:ok)

          expect(graphql_data['echo']).to eq('nil says: Hello world')
        end
      end
    end
  end

  describe 'testing for Gitaly calls' do
    let(:project) { create(:project, :repository) }
    let(:user) { create(:user) }

    let(:query) do
      graphql_query_for('project', { 'fullPath' => project.full_path }, %w(id))
    end

    before do
      project.add_developer(user)
    end

    it_behaves_like 'a working graphql query' do
      before do
        post_graphql(query, current_user: user)
      end
    end

    context 'when Gitaly is called' do
      before do
        allow(Gitlab::GitalyClient).to receive(:get_request_count).and_return(1, 2)
      end

      it "logs a warning that the 'calls_gitaly' field declaration is missing" do
        expect(Gitlab::ErrorTracking).to receive(:track_and_raise_for_dev_exception).once

        post_graphql(query, current_user: user)
      end
    end
  end

  describe 'resolver complexity' do
    let_it_be(:project) { create(:project, :public) }
    let(:query) do
      graphql_query_for(
        'project',
        { 'fullPath' => project.full_path },
        query_graphql_field(resource, {}, 'edges { node { iid } }')
      )
    end

    before do
      stub_const('GitlabSchema::DEFAULT_MAX_COMPLEXITY', 6)
    end

    context 'when fetching single resource' do
      let(:resource) { 'issues(first: 1)' }

      it 'processes the query' do
        post_graphql(query)

        expect(graphql_errors).to be_nil
      end
    end

    context 'when fetching too many resources' do
      let(:resource) { 'issues(first: 100)' }

      it 'returns an error' do
        post_graphql(query)

        expect_graphql_errors_to_include(/which exceeds max complexity/)
      end
    end
  end

  describe 'complexity limits' do
    let_it_be(:project) { create(:project, :public) }
    let!(:user) { create(:user) }

    let(:query_fields) do
      <<~QUERY
      id
      QUERY
    end

    let(:query) do
      graphql_query_for(
        'project',
        { 'fullPath' => project.full_path },
        query_fields
      )
    end

    before do
      stub_const('GitlabSchema::DEFAULT_MAX_COMPLEXITY', 1)
    end

    context 'unauthenticated user' do
      subject { post_graphql(query) }

      it 'raises a complexity error' do
        subject

        expect_graphql_errors_to_include(/which exceeds max complexity/)
      end
    end

    context 'authenticated user' do
      subject { post_graphql(query, current_user: user) }

      it 'does not raise an error as it uses the `AUTHENTICATED_COMPLEXITY`' do
        subject

        expect(graphql_errors).to be_nil
      end
    end
  end

  describe 'keyset pagination' do
    let_it_be(:project) { create(:project, :public) }
    let_it_be(:issues) { create_list(:issue, 10, project: project, created_at: Time.now.change(usec: 200)) }

    let(:page_size) { 6 }
    let(:issues_edges) { %w(data project issues edges) }
    let(:end_cursor) { %w(data project issues pageInfo endCursor) }
    let(:query) do
      <<~GRAPHQL
        query project($fullPath: ID!, $first: Int, $after: String) {
            project(fullPath: $fullPath) {
              issues(first: $first, after: $after) {
                edges { node { iid } }
                pageInfo { endCursor }
              }
            }
        }
      GRAPHQL
    end

    # TODO: Switch this to use `post_graphql`
    # This is not performing an actual GraphQL request because the
    # variables end up being strings when passed through the `post_graphql`
    # helper.
    #
    # https://gitlab.com/gitlab-org/gitlab/-/issues/222432
    def execute_query(after: nil)
      GitlabSchema.execute(
        query,
        context: { current_user: nil },
        variables: {
          fullPath: project.full_path,
          first: page_size,
          after: after
        }
      )
    end

    it 'paginates datetimes correctly when they have millisecond data' do
      # let's make sure we're actually querying a timestamp, just in case
      expect(Gitlab::Graphql::Pagination::Keyset::QueryBuilder)
        .to receive(:new).with(anything, anything, hash_including('created_at'), anything).and_call_original

      first_page = execute_query
      edges = first_page.dig(*issues_edges)
      cursor = first_page.dig(*end_cursor)

      expect(edges.count).to eq(6)
      expect(edges.last['node']['iid']).to eq(issues[4].iid.to_s)

      second_page = execute_query(after: cursor)
      edges = second_page.dig(*issues_edges)

      expect(edges.count).to eq(4)
      expect(edges.last['node']['iid']).to eq(issues[0].iid.to_s)
    end
  end
end
