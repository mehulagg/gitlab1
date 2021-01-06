# frozen_string_literal: true

module WebEngine
  class Engine < ::Rails::Engine
    initializer :before_set_eager_paths, before: :set_load_path do
      config.eager_load_paths.push(*%W[#{config.root}/lib
                                       #{config.root}/app/graphql/resolvers/concerns
                                       #{config.root}/app/graphql/mutations/concerns
                                       #{config.root}/app/graphql/types/concerns])

      if Gitlab.ee?
        ee_paths = config.eager_load_paths.each_with_object([]) do |path, memo|
          ee_path = config.root
                      .join('ee', Pathname.new(path).relative_path_from(config.root))
          memo << ee_path.to_s
        end
        # Eager load should load CE first
        config.eager_load_paths.push(*ee_paths)
      end
    end
  end
end
