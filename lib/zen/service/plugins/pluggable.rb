# frozen_string_literal: true

module Zen
  module Service::Plugins
    module Pluggable
      def use(name, **opts)
        extension = Service::Plugins.fetch(name)

        include extension

        defaults = extension.config[:default_options]
        opts = defaults.merge(opts) unless defaults.nil?

        extend extension::ClassMethods if extension.const_defined?(:ClassMethods)

        extension.used(self, **opts) if extension.respond_to?(:used)

        plugins[name] = Reflection.new(extension, opts)

        extension
      end

      def using?(name)
        plugins.key?(name)
      end

      def plugins
        @plugins ||= {}
      end
      alias extensions plugins

      Reflection = Struct.new(:extension, :options)
    end
  end
end
