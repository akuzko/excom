module Excom
  module Plugins::Rescue
    Plugins.register :rescue, self

    def self.used(service_class, *)
      service_class.use(:status) unless service_class.using?(:status)
      service_class.add_execution_prop :error
    end

    def execute(**opts)
      rezcue = opts.delete(:rescue)
      super
    rescue StandardError => error
      clear_execution_state!
      failure!(:error)
      state.error = error
      raise error unless rezcue
      self
    end

    def error
      state.error
    end

    def error?
      status == :error
    end
  end
end
