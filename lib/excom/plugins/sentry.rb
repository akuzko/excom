module Excom
  module Plugins::Sentry
    autoload :Sentinel, 'excom/plugins/sentry/sentinel'

    Plugins.register :sentry, self

    def self.used(service_class, **opts)
      klass = opts[:class]

      service_class.use(:status) unless service_class.using?(:status)
      service_class._sentry_class = klass if klass
    end

    def execute(*)
      reason = why_cant?(:execute)

      return super if reason.nil?

      failure!(reason)

      self
    end

    def can?(action)
      why_cant?(action).nil?
    end

    def why_cant?(action)
      sentry.denial_reason(action)
    end

    def sentry
      @sentry ||= self.class.sentry_class.new(self)
    end

    def sentry_hash
      sentry.to_hash
    end

    module ClassMethods
      attr_writer :_sentry_class

      def inherited(service_class)
        super
        service_class.sentry_class(_sentry_class)
      end

      def sentry_class(klass = UNDEFINED)
        return self._sentry_class = klass unless klass == UNDEFINED
        return @sentry_class if defined? @sentry_class

        @sentry_class =
          if _sentry_class.is_a?(String)
            return _sentry_class.constantize if _sentry_class.respond_to?(:constantize)

            names = _sentry_class.split('::'.freeze)
            names.shift if names.first.empty?
            names.reduce(Object){ |obj, name| obj.const_get(name) }
          else
            _sentry_class
          end

        @sentry_class.service_class = self
        @sentry_class
      end

      def _sentry_class
        @_sentry_class ||= "#{name}Sentry"
      end

      def sentry(delegate: [], &block)
        (plugins[:sentry].options[:delegate] ||= []).concat(delegate).uniq!

        if const_defined?(:Sentry)
          const_get(:Sentry).class_eval(&block)
        else
          @_sentry_class = @sentry_class = Class.new(Sentry, &block)
          @sentry_class.service_class = self
          const_set(:Sentry, @_sentry_class)
        end
      end
    end
  end
end
