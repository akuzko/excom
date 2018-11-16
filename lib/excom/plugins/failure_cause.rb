module Excom
  module Plugins::FailureCause
    Plugins.register :failure_cause, self,
      default_options: {cause_method_name: :cause}

    def self.used(service_class, cause_method_name:) do
      service_class.add_execution_prop(:cause)
      service_class.send(:define_method, cause_method_name) { state.cause }
    end

    private def assign_failed_result(value)
      state.result = nil
      state.cause = value
    end
  end
end
