module Zemu
    # Configuration object.
    #
    # An object which represents the configuration of a Zemu emulator.
    class Config
        # Memory object.
        #
        # This is an abstract class from which all other memory objects inherit.
        class Memory
            # Address of the memory section.
            # This will be a value between 0x0000 and 0xFFFF.
            attr_reader :address

            # Size of the memory section.
            attr_reader :size

            def initialize
                raise NotImplementedError, "Cannot construct an instance of the abstract class Zemu::Config::Memory."
            end
        end

        # The name of the configuration.
        # This will also be the name of the generated executable
        # when the emulator is built.
        attr_reader :name

        # The path to the compiler to use when building.
        # By default this is +clang+, with no path reference.
        attr_reader :compiler

        # Constructor.
        #
        # Takes a block in which parameters of the configuration
        # can be initialized.
        #
        # All parameters can be set within this block.
        # They become readonly as soon as the block completes.
        #
        # @example
        #
        #   Zemu::Config.new do |c|
        #       c.name = "my_config"
        #   end
        #
        # @raise [Zemu::ConfigError] Raised if the +name+ parameter is not set, or contains whitespace.
        def initialize
            @initialized = false

            @name = nil
            @compiler = "clang"

            yield self

            @initialized = true

            if @name.nil?
                raise ConfigError, "Name must be set."
            end

            if @name.empty?
                raise ConfigError, "Name cannot be empty."
            end

            if /\s/ =~ @name
                raise ConfigError, "Name cannot contain whitespace."
            end
        end

        private :method_missing

        # @private
        # This allows some metaprogramming magic to allow the user to set instance variables
        # (config parameters) while initializing the configuration object, but ensures
        # that these parameters are readonly once the object is initialized.
        def method_missing(m, *args, &block)
            # We don't allow the setting of instance variables if the object
            # has been initialized.
            if @initialized
                super
            end

            %w[name compiler].each do |v|
                if m == "#{v}=".to_sym
                    instance_variable_set("@#{v}", args[0])
                    return
                end
            end

            # Otherwise just call super's method_missing
            super
        end
    end

    class ConfigError < StandardError
        def initialize(msg="The configuration is invalid.")
            super
        end
    end
end