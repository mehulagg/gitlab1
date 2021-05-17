# frozen_string_literal: true

if ENV['ENABLE_RBTRACE']
  Gitlab::Cluster::LifecycleEvents.on_worker_start do
    # TODO: is it still relevant for Puma?
    # Unicorn clears out signals before it forks, so rbtrace won't work
    # unless it is enabled after the fork.
    require 'rbtrace'
  end
end
