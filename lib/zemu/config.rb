module Zemu
    # Configuration object.
    #
    # An object which represents the configuration of a Zemu emulator.
    class Config
        # Name of the configuration.
        #
        # This will also be the name of the generated executable when the emulator
        # is built.
        #
        # A Zemu::ConfigError will be raised if this is not set by the initialization block.
        attr_accessor :name

        # Compiler.
        #
        # This is the path to the compiler used to build the executable.
        #
        # The default is +clang+. This means that the +clang+ executable is expected
        # to be on the path when the executable is built, as there is no path specified.
        attr_reader :compiler

        # Constructor.
        #
        # Takes a block in which parameters of the configuration
        # can be initialized.
        #
        # === Example
        #
        #   Zemu::Config.new do |c|
        #       c.name = "my_config"
        #   end
        #
        # === Exceptions Raised
        #
        # [Zemu::ConfigError] Raised if the name parameter is not set, or contains whitespace.
        def initialize
            @name = nil
            @compiler = "clang"

            yield self

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
    end

    class ConfigError < StandardError
        def initialize(msg="The configuration is invalid.")
            super
        end
    end
end