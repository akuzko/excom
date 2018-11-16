module Excom
  module Plugins::Errors
    Plugins.register :errors, self,
      default_options: {errors_class: Hash, fail_if_present: true}

    def self.used(service_class, *)
      service_class.add_execution_prop(:errors)
    end

    def execute(*)
      super

      if self.class.plugins[:errors].options[:fail_if_present] && !errors.empty?
        failure!
      end

      self
    end

    private def initialize(*)
      super
      state.errors = errors_class.new
    end

    def errors
      state.errors
    end

    private def errors_class
      self.class.plugins[:errors].options[:errors_class]
    end

    private def clear_execution_state!
      super
      state.errors = errors_class.new
    end
  end
end
