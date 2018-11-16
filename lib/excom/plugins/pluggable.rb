module Excom
  module Plugins::Pluggable
    def use(name, **opts)
      extension = Plugins.fetch(name)

      method = extension.excom_options[:use_with] || :include
      send(method, extension)

      defaults = extension.excom_options[:default_options]
      opts = defaults.merge(opts) unless defaults.nil?

      if extension.const_defined?('ClassMethods')
        extend extension::ClassMethods
      end

      if extension.respond_to?(:used)
        extension.used(self, **opts)
      end

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
