module Zemu
    # Configuration object
    #
    # An object which represents the configuration of a Zemu emulator.
    class Config
        attr_accessor :name

        # Constructor.
        #
        # Takes a block in which parameters of the configuration
        # can be initialized.
        #
        # @example
        #
        #   Zemu::Config.new do |c|
        #       c.name = "my_config"
        #   end
        #
        # @param [Block] a block in which the configuration's parameters are initialized.
        #
        # @return [Zemu::Config] the configuration.
        def initialize
            @name = nil

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