module Gitlab
  module Metrics
    # Module for instrumenting methods.
    #
    # This module allows instrumenting of methods without having to actually
    # alter the target code (e.g. by including modules).
    #
    # Example usage:
    #
    #     Gitlab::Metrics::Instrumentation.instrument_method(User, :by_login)
    module Instrumentation
      SERIES = 'method_calls'

      PROXY_IVAR = :@__gitlab_instrumentation_proxy

      def self.configure
        yield self
      end

      # Instruments a class method.
      #
      # mod  - The module to instrument as a Module/Class.
      # name - The name of the method to instrument.
      def self.instrument_method(mod, name)
        instrument(:class, mod, name)
      end

      # Instruments an instance method.
      #
      # mod  - The module to instrument as a Module/Class.
      # name - The name of the method to instrument.
      def self.instrument_instance_method(mod, name)
        instrument(:instance, mod, name)
      end

      # Recursively instruments all subclasses of the given root module.
      #
      # This can be used to for example instrument all ActiveRecord models (as
      # these all inherit from ActiveRecord::Base).
      #
      # This method can optionally take a block to pass to `instrument_methods`
      # and `instrument_instance_methods`.
      #
      # root - The root module for which to instrument subclasses. The root
      #        module itself is not instrumented.
      def self.instrument_class_hierarchy(root, &block)
        visit = root.subclasses

        until visit.empty?
          klass = visit.pop

          instrument_methods(klass, &block)
          instrument_instance_methods(klass, &block)

          klass.subclasses.each { |c| visit << c }
        end
      end

      # Instruments all public and private methods of a module.
      #
      # This method optionally takes a block that can be used to determine if a
      # method should be instrumented or not. The block is passed the receiving
      # module and an UnboundMethod. If the block returns a non truthy value the
      # method is not instrumented.
      #
      # mod - The module to instrument.
      def self.instrument_methods(mod)
        methods = mod.methods(false) + mod.private_methods(false)
        methods.each do |name|
          method = mod.method(name)

          if method.owner == mod.singleton_class
            if !block_given? || block_given? && yield(mod, method)
              instrument_method(mod, name)
            end
          end
        end
      end

      # Instruments all public and private instance methods of a module.
      #
      # See `instrument_methods` for more information.
      #
      # mod - The module to instrument.
      def self.instrument_instance_methods(mod)
        methods = mod.instance_methods(false) + mod.private_instance_methods(false)
        methods.each do |name|
          method = mod.instance_method(name)

          if method.owner == mod
            if !block_given? || block_given? && yield(mod, method)
              instrument_instance_method(mod, name)
            end
          end
        end
      end

      # Returns true if a module is instrumented.
      #
      # mod - The module to check
      def self.instrumented?(mod)
        mod.instance_variable_defined?(PROXY_IVAR)
      end

      # Returns the proxy module (if any) of `mod`.
      def self.proxy_module(mod)
        mod.instance_variable_get(PROXY_IVAR)
      end

      # Instruments a method.
      #
      # type - The type (:class or :instance) of method to instrument.
      # mod  - The module containing the method.
      # name - The name of the method to instrument.
      def self.instrument(type, mod, name)
        return unless Metrics.enabled?

        name   = name.to_sym
        target = type == :instance ? mod : mod.singleton_class

        if type == :instance
          target = mod
          label  = "#{mod.name}##{name}"
          method = mod.instance_method(name)
        else
          target = mod.singleton_class
          label  = "#{mod.name}.#{name}"
          method = mod.method(name)
        end

        unless instrumented?(target)
          target.instance_variable_set(PROXY_IVAR, Module.new)
        end

        proxy_module = self.proxy_module(target)

        # Some code out there (e.g. the "state_machine" Gem) checks the arity of
        # a method to make sure it only passes arguments when the method expects
        # any. If we were to always overwrite a method to take an `*args`
        # signature this would break things. As a result we'll make sure the
        # generated method _only_ accepts regular arguments if the underlying
        # method also accepts them.
        if method.arity == 0
          args_signature = '&block'
        else
          args_signature = '*args, &block'
        end

        proxy_module.class_eval <<-EOF, __FILE__, __LINE__ + 1
          def #{name}(#{args_signature})
            trans = Gitlab::Metrics::Instrumentation.transaction

            if trans
              start     = Time.now
              cpu_start = Gitlab::Metrics::System.cpu_time
              retval    = super
              duration  = (Time.now - start) * 1000.0

              if duration >= Gitlab::Metrics.method_call_threshold
                cpu_duration = Gitlab::Metrics::System.cpu_time - cpu_start

                trans.add_metric(Gitlab::Metrics::Instrumentation::SERIES,
                                 { duration: duration, cpu_duration: cpu_duration },
                                 method: #{label.inspect})
              end

              retval
            else
              super
            end
          end
        EOF

        target.prepend(proxy_module)
      end

      # Small layer of indirection to make it easier to stub out the current
      # transaction.
      def self.transaction
        Transaction.current
      end
    end
  end
end
