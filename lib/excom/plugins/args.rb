module Excom
  module Plugins::Args
    Plugins.register :args, self

    def initialize(*args)
      args, opts = resolve_args!(args)

      assert_valid_args!(args)
      assert_valid_opts!(opts)

      @args = args
      @opts = opts

      super
    end

    def initialize_clone(*)
      super
      @args = @args.dup unless @args.nil?
      @opts = @opts.dup unless @opts.nil?
    end

    def with_args(*args)
      clone.tap{ |copy| copy.args.replace(args) }
    end

    def with_opts(opts)
      clone.tap{ |copy| copy.opts.merge!(opts) }
    end

    protected def opts
      @opts
    end

    protected def args
      @args
    end

    private def resolve_args!(args)
      opts = args.last.is_a?(Hash) ? args.pop : {}

      if args.length < self.class.args_list.length
        rest = opts
        opts = self.class.opts_list.each_with_object({}) do |key, ops|
          ops[key] = rest[key]
          rest.delete(key)
        end

        args.push(rest) unless rest.empty?
      end

      return args, opts
    end

    private def assert_valid_args!(actual)
      allowed = self.class.args_list.length

      if actual.length > allowed
        fail ArgumentError, "wrong number of args (given #{actual.length}, expected 0..#{allowed})"
      end
    end

    private def assert_valid_opts!(actual)
      unexpected = actual.keys - self.class.opts_list

      if unexpected.any?
        fail ArgumentError, "wrong opts #{unexpected} given"
      end
    end

    module ClassMethods
      def inherited(service_class)
        service_class.const_set(:ArgMethods, Module.new)
        service_class.send(:include, service_class::ArgMethods)
        service_class.args_list.replace args_list.dup
        service_class.opts_list.replace opts_list.dup
        super
      end

      def arg_methods
        const_get(:ArgMethods)
      end

      def args(*argz)
        args_list.concat(argz)

        argz.each_with_index do |name, i|
          arg_methods.send(:define_method, name){ @args[i] }
        end
      end

      def opts(*optz)
        opts_list.concat(optz)

        optz.each do |name|
          arg_methods.send(:define_method, name){ @opts[name] }
        end
      end

      def args_list
        @args_list ||= []
      end

      def opts_list
        @opts_list ||= []
      end
    end
  end
end
