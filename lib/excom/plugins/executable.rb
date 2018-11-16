require 'ostruct'

module Excom
  module Plugins::Executable
    Plugins.register :executable, self

    class State
      def self.prop_names
        @prop_names ||= []
      end

      def self.add_prop(*props)
        prop_names.push(*props)
        props.each{ |prop| def_prop_accessor(prop) }
      end

      def self.def_prop_accessor(name)
        define_method(name) { @values[name] }
        define_method("#{name}=") { |value| @values[name] = value }
        define_method("has_#{name}?") { @values.key?(name) }
      end

      def initialize(values = {})
        @values = values
      end

      def clear!
        @values.clear
      end

      def prop_names
        self.class.prop_names
      end

      def replace(other)
        missing_props = prop_names - other.prop_names

        unless missing_props.empty?
          fail ArgumentError, "cannot accept execution state #{other} due to missing props: #{missing_props}"
        end

        prop_names.each do |prop|
          @values[prop] = other.public_send(prop)
        end
      end
    end

    def self.used(service_class, *)
      service_class.const_set(:State, Class.new(State))
      service_class.add_execution_prop(:executed, :success, :result)
    end

    attr_reader :state

    def initialize(*)
      @state = self.class::State.new(executed: false)
    end

    def initialize_clone(*)
      clear_execution_state!
    end

    def execute(*, &block)
      clear_execution_state!
      result = execute!(&block)
      result_with(result) unless state.has_result?
      state.executed = true

      self
    end

    def executed?
      state.executed
    end

    def ~@
      state
    end

    private def execute!
      success!
    end

    private def clear_execution_state!
      state.clear!
      state.executed = false
    end

    private def success
      success!
      assign_successful_result(yield)
    end

    private def failure
      failure!
      assign_failed_result(yield)
    end

    private def success!
      state.success = true
      state.result = nil
    end

    private def failure!
      state.success = false
      state.result = nil
    end

    private def assign_successful_result(value)
      state.result = value
    end

    private def assign_failed_result(value)
      state.result = value
    end

    def result
      return state.result unless block_given?

      result_with(yield)
    end

    private def result_with(obj)
      if State === obj
        state.replace(obj)
      end

      state.success = !!obj
      if state.success
        assign_successful_result(obj)
      else
        assign_failed_result(obj)
      end
    end

    def success?
      state.success == true
    end

    def failure?
      !success?
    end

    module ClassMethods
      def inherited(klass)
        klass.const_set(:State, Class.new(self::State))
        klass::State.prop_names.replace(self::State.prop_names.dup)
      end

      def add_execution_prop(*props)
        self::State.add_prop(*props)
      end

      def call(*args)
        new(*args).execute
      end
      alias_method :execute, :call

      def [](*args)
        call(*args).result
      end

      def method_added(name)
        private :execute! if name == :execute!
        super if defined? super
      end
    end
  end
end
