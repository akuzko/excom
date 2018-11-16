module Excom
  module Plugins::Status
    Plugins.register :status, self,
      default_options: {success: [], failure: []}

    def self.used(service_class, success:, failure:)
      service_class.add_execution_prop(:status)

      helpers = Module.new do
        success.each do |name|
          define_method(name) do |result = nil|
            success(name) { result }
          end
        end

        failure.each do |name|
          define_method(name) do |result = nil|
            failure(name) { result }
          end
        end
      end

      service_class.const_set('StatusHelpers', helpers)
      service_class.send(:include, helpers)
    end

    def status
      state.status
    end

    private def success!(status = :success)
      state.status = status
      super()
    end

    private def success(status = :success, &block)
      state.status = status
      super(&block)
    end

    private def failure!(status = :failure)
      state.status = status
      super()
    end

    private def failure(status = :failure, &block)
      state.status = status
      super(&block)
    end

    # private def finish_with!(status, success:)
    #   @success = success
    #   @status = status
    #   @cause = nil
    #   @result = nil
    # end

    # private def success!(status = :success)
    #   finish_with!(status, success: true)
    # end

    # private def success(status = :success)
    #   success!(status)
    #   @result = yield
    # end

    # private def failure!(status = fail_with)
    #   finish_with!(status, success: false)
    # end

    # private def failure(status = fail_with)
    #   failure!(status)
    #   @cause = yield
    # end
  end
end
