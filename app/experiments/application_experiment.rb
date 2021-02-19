# frozen_string_literal: true

class ApplicationExperiment < Gitlab::Experiment # rubocop:disable Gitlab/NamespacedClass
  def enabled?
    return false if Feature::Definition.get(feature_flag_name).nil? # there has to be a feature flag yaml file
    return false unless Gitlab.dev_env_or_com? # we're in an environment that allows experiments

    Feature.get(feature_flag_name).state != :off # rubocop:disable Gitlab/AvoidFeatureGet
  end

  def publish(_result)
    track(:assignment) # track that we've assigned a variant for this context
    Gon.global.push({ experiment: { name => signature } }, true) # push to client
  end

  def track(action, **event_args)
    return unless should_track? # no events for opted out actors or excluded subjects

    Gitlab::Tracking.event(name, action.to_s, **event_args.merge(
      context: (event_args[:context] || []) << SnowplowTracker::SelfDescribingJson.new(
        'iglu:com.gitlab/gitlab_experiment/jsonschema/0-3-0', signature
      )
    ))
  end

  def exclude!
    # this will get moved to the gem.
    @excluded = true
  end

  def rollout_strategy
    # no-op override in inherited class as desired
  end

  def variants
    # override as desired in inherited class with all variants + control
    # %i[variant1 variant2 control]
    #
    # this will make sure we supply variants as these go together - rollout_strategy of :round_robin must have variants
    raise NotImplementedError, "Inheriting class must supply variants as an array if :round_robin strategy is used" if rollout_strategy == :round_robin
  end

  private

  def feature_flag_name
    name.tr('/', '_')
  end

  def resolve_variant_name
    case rollout_strategy
    when :round_robin
      round_robin_rollout
    else
      percentage_rollout
    end
  end

  def round_robin_rollout
    Strategy::RoundRobin.new(feature_flag_name, variants).execute
  end

  def percentage_rollout
    return variant_names.first if Feature.enabled?(feature_flag_name, self, type: :experiment, default_enabled: :yaml)

    nil # Returning nil vs. :control is important for not caching and rollouts.
  end

  # Cache is an implementation on top of Gitlab::Redis::SharedState that also
  # adheres to the ActiveSupport::Cache::Store interface and uses the redis
  # hash data type.
  #
  # Since Gitlab::Experiment can use any type of caching layer, utilizing the
  # long lived shared state interface here gives us an efficient way to store
  # context keys and the variant they've been assigned -- while also giving us
  # a simple way to clean up an experiments data upon resolution.
  #
  # The data structure:
  #   key: experiment.name
  #   fields: context key => variant name
  #
  # The keys are expected to be `experiment_name:context_key`, which is the
  # default cache key strategy. So running `cache.fetch("foo:bar", "value")`
  # would create/update a hash with the key of "foo", with a field named
  # "bar" that has "value" assigned to it.
  class Cache < ActiveSupport::Cache::Store # rubocop:disable Gitlab/NamespacedClass
    # Clears the entire cache for a given experiment. Be careful with this
    # since it would reset all resolved variants for the entire experiment.
    def clear(key:)
      key = hkey(key)[0] # extract only the first part of the key
      pool do |redis|
        case redis.type(key)
        when 'hash', 'none' then redis.del(key)
        else raise ArgumentError, 'invalid call to clear a non-hash cache key'
        end
      end
    end

    private

    def pool
      raise ArgumentError, 'missing block' unless block_given?

      Gitlab::Redis::SharedState.with { |redis| yield redis }
    end

    def hkey(key)
      key.to_s.split(':') # this assumes the default strategy in gitlab-experiment
    end

    def read_entry(key, **options)
      value = pool { |redis| redis.hget(*hkey(key)) }
      value.nil? ? nil : ActiveSupport::Cache::Entry.new(value)
    end

    def write_entry(key, entry, **options)
      return false if entry.value.blank? # don't cache any empty values

      pool { |redis| redis.hset(*hkey(key), entry.value) }
    end

    def delete_entry(key, **options)
      pool { |redis| redis.hdel(*hkey(key)) }
    end
  end
end
