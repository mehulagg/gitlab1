# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Database::LoadBalancing::LoadBalancer, :request_store do
  let(:pool_spec) { ActiveRecord::Base.connection_pool.spec }
  let(:pool) { ActiveRecord::ConnectionAdapters::ConnectionPool.new(pool_spec) }
  let(:conflict_error) { Class.new(RuntimeError) }

  let(:lb) { described_class.new(%w(localhost localhost)) }

  before do
    allow(Gitlab::Database).to receive(:create_connection_pool)
      .and_return(pool)
    stub_const(
      'Gitlab::Database::LoadBalancing::LoadBalancer::PG::TRSerializationFailure',
      conflict_error
    )
  end

  def raise_and_wrap(wrapper, original)
    raise original
  rescue original.class
    raise wrapper.new('boop')
  end

  def wrapped_exception(wrapper, original)
    raise_and_wrap(wrapper, original.new)
  rescue wrapper => error
    error
  end

  def twice_wrapped_exception(top, middle, original)
    begin
      raise_and_wrap(middle, original.new)
    rescue middle => middle_error
      raise_and_wrap(top, middle_error)
    end
  rescue top => top_error
    top_error
  end

  describe '#read' do
    it 'yields a connection for a read' do
      connection = double(:connection)
      host = double(:host)

      allow(lb).to receive(:host).and_return(host)
      allow(host).to receive(:query_cache_enabled).and_return(true)

      expect(host).to receive(:connection).and_return(connection)

      expect { |b| lb.read(&b) }.to yield_with_args(connection)
    end

    it 'ensures that query cache is enabled' do
      connection = double(:connection)
      host = double(:host)

      allow(lb).to receive(:host).and_return(host)
      allow(host).to receive(:query_cache_enabled).and_return(false)
      allow(host).to receive(:connection).and_return(connection)

      expect(host).to receive(:enable_query_cache!).once

      lb.read { 10 }
    end

    it 'marks hosts that are offline' do
      allow(lb).to receive(:connection_error?).and_return(true)

      expect(lb.host_list.hosts[0]).to receive(:offline!)
      expect(lb).to receive(:release_host)

      raised = false

      returned = lb.read do
        unless raised
          raised = true
          raise
        end

        10
      end

      expect(returned).to eq(10)
    end

    it 'retries a query in the event of a serialization failure' do
      raised = false

      expect(lb).to receive(:release_host)

      returned = lb.read do
        unless raised
          raised = true
          raise conflict_error.new
        end

        10
      end

      expect(returned).to eq(10)
    end

    it 'retries every host at most 3 times when a query conflict is raised' do
      expect(lb).to receive(:release_host).exactly(6).times
      expect(lb).to receive(:read_write)

      lb.read { raise conflict_error.new }
    end

    it 'uses the primary if no secondaries are available' do
      allow(lb).to receive(:connection_error?).and_return(true)

      expect(lb.host_list.hosts).to all(receive(:online?).and_return(false))

      expect(lb).to receive(:read_write).and_call_original

      expect { |b| lb.read(&b) }
        .to yield_with_args(ActiveRecord::Base.retrieve_connection)
    end
  end

  describe '#read_write' do
    it 'yields a connection for a write' do
      expect { |b| lb.read_write(&b) }
        .to yield_with_args(ActiveRecord::Base.retrieve_connection)
    end

    it 'uses a retry with exponential backoffs' do
      expect(lb).to receive(:retry_with_backoff).and_yield

      lb.read_write { 10 }
    end
  end

  describe '#db_role_for_connection' do
    context 'when the load balancer creates the connection with #read' do
      it 'returns :replica' do
        role = nil
        lb.read do |connection|
          role = lb.db_role_for_connection(connection)
        end

        expect(role).to be(:replica)
      end
    end

    context 'when the load balancer creates the connection with #read_write' do
      it 'returns :primary' do
        role = nil
        lb.read_write do |connection|
          role = lb.db_role_for_connection(connection)
        end

        expect(role).to be(:primary)
      end
    end

    context 'when the load balancer falls back the connection creation to primary' do
      it 'returns :primary' do
        allow(lb).to receive(:serialization_failure?).and_return(true)

        role = nil
        raised = 7 # 2 hosts = 6 retries

        lb.read do |connection|
          if raised > 0
            raised -= 1
            raise
          end

          role = lb.db_role_for_connection(connection)
        end

        expect(role).to be(:primary)
      end
    end

    context 'when the load balancer uses replica after recovery from a failure' do
      it 'returns :replica' do
        allow(lb).to receive(:connection_error?).and_return(true)

        role = nil
        raised = false

        lb.read do |connection|
          unless raised
            raised = true
            raise
          end

          role = lb.db_role_for_connection(connection)
        end

        expect(role).to be(:replica)
      end
    end

    context 'when the connection does not come from the load balancer' do
      it 'returns nil' do
        connection = double(:connection)

        expect(lb.db_role_for_connection(connection)).to be(nil)
      end
    end
  end

  describe '#host' do
    it 'returns the secondary host to use' do
      expect(lb.host).to be_an_instance_of(Gitlab::Database::LoadBalancing::Host)
    end

    it 'stores the host in a thread-local variable' do
      RequestStore.delete(described_class::CACHE_KEY)

      expect(lb.host_list).to receive(:next).once.and_call_original

      lb.host
      lb.host
    end
  end

  describe '#release_host' do
    it 'releases the host and its connection' do
      host = lb.host

      expect(host).to receive(:disable_query_cache!)

      lb.release_host

      expect(RequestStore[described_class::CACHE_KEY]).to be_nil
    end
  end

  describe '#release_primary_connection' do
    it 'releases the connection to the primary' do
      expect(ActiveRecord::Base.connection_pool).to receive(:release_connection)

      lb.release_primary_connection
    end
  end

  describe '#primary_write_location' do
    it 'returns a String' do
      expect(lb.primary_write_location).to be_an_instance_of(String)
    end

    it 'raises an error if the write location could not be retrieved' do
      connection = double(:connection)

      allow(lb).to receive(:read_write).and_yield(connection)
      allow(connection).to receive(:select_all).and_return([])

      expect { lb.primary_write_location }.to raise_error(RuntimeError)
    end

    it 'fallbacks to #get_replay_write_location when #get_write_location raises error' do
      connection = double(:connection)
      allow(lb).to receive(:read_write).and_yield(connection)
      allow(::Gitlab::Database).to receive(:get_write_location).and_raise(ActiveRecord::StatementInvalid)
      expect(::Gitlab::Database).to receive(:get_replay_write_location).and_return('0/C73A0D88')

      lb.primary_write_location
    end
  end

  describe '#all_caught_up?' do
    it 'returns true if all hosts caught up to the write location' do
      expect(lb.host_list.hosts).to all(receive(:caught_up?).with('foo').and_return(true))

      expect(lb.all_caught_up?('foo')).to eq(true)
    end

    it 'returns false if a host has not yet caught up' do
      expect(lb.host_list.hosts[0]).to receive(:caught_up?)
        .with('foo')
        .and_return(true)

      expect(lb.host_list.hosts[1]).to receive(:caught_up?)
        .with('foo')
        .and_return(false)

      expect(lb.all_caught_up?('foo')).to eq(false)
    end
  end

  describe '#retry_with_backoff' do
    it 'returns the value returned by the block' do
      value = lb.retry_with_backoff { 10 }

      expect(value).to eq(10)
    end

    it 're-raises errors not related to database connections' do
      expect(lb).not_to receive(:sleep) # to make sure we're not retrying

      expect { lb.retry_with_backoff { raise 'boop' } }
        .to raise_error(RuntimeError)
    end

    it 'retries the block when a connection error is raised' do
      allow(lb).to receive(:connection_error?).and_return(true)
      expect(lb).to receive(:sleep).with(2)
      expect(lb).to receive(:release_primary_connection)

      raised = false
      returned = lb.retry_with_backoff do
        unless raised
          raised = true
          raise
        end

        10
      end

      expect(returned).to eq(10)
    end

    it 're-raises the connection error if the retries did not succeed' do
      allow(lb).to receive(:connection_error?).and_return(true)
      expect(lb).to receive(:sleep).with(2).ordered
      expect(lb).to receive(:sleep).with(4).ordered
      expect(lb).to receive(:sleep).with(16).ordered

      expect(lb).to receive(:release_primary_connection).exactly(3).times

      expect { lb.retry_with_backoff { raise } }.to raise_error(RuntimeError)
    end
  end

  describe '#connection_error?' do
    before do
      stub_const('Gitlab::Database::LoadBalancing::LoadBalancer::CONNECTION_ERRORS',
                 [NotImplementedError])
    end

    it 'returns true for a connection error' do
      error = NotImplementedError.new

      expect(lb.connection_error?(error)).to eq(true)
    end

    it 'returns true for a wrapped connection error' do
      wrapped = wrapped_exception(ActiveRecord::StatementInvalid, NotImplementedError)

      expect(lb.connection_error?(wrapped)).to eq(true)
    end

    it 'returns true for a wrapped connection error from a view' do
      wrapped = wrapped_exception(ActionView::Template::Error, NotImplementedError)

      expect(lb.connection_error?(wrapped)).to eq(true)
    end

    it 'returns true for deeply wrapped/nested errors' do
      top = twice_wrapped_exception(ActionView::Template::Error, ActiveRecord::StatementInvalid, NotImplementedError)

      expect(lb.connection_error?(top)).to eq(true)
    end

    it 'returns true for an invalid encoding error' do
      error = RuntimeError.new('invalid encoding name: unicode')

      expect(lb.connection_error?(error)).to eq(true)
    end

    it 'returns false for errors not related to database connections' do
      error = RuntimeError.new

      expect(lb.connection_error?(error)).to eq(false)
    end
  end

  describe '#serialization_failure?' do
    let(:conflict_error) { Class.new(RuntimeError) }

    before do
      stub_const(
        'Gitlab::Database::LoadBalancing::LoadBalancer::PG::TRSerializationFailure',
        conflict_error
      )
    end

    it 'returns for a serialization error' do
      expect(lb.serialization_failure?(conflict_error.new)).to eq(true)
    end

    it 'returns true for a wrapped error' do
      wrapped = wrapped_exception(ActionView::Template::Error, conflict_error)

      expect(lb.serialization_failure?(wrapped)).to eq(true)
    end
  end
end
