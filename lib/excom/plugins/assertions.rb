module Excom
  module Plugins::Assertions
    Plugins.register :assertions, self

    def assert
      if yield
        success! unless state.has_success?
      else
        failure!
      end
    end
  end
end
