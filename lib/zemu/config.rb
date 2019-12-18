module Zemu
        # Abstract configuration object.
    # All configuration objects should inherit from this.
    class ConfigObject
        # Defines the parameters of this configuration object.
        def params
            raise NotImplementedError, "params must be overridden by inheriting class."
        end

        protected :params

        # Defines the initial values of parameters, if any.
        def params_init
            return {}
        end

        protected :params_init

        def initialize
            @initialized = false

            # Initialize each parameter to nil
            params.each do |p|
                if params_init[p].nil?
                    instance_variable_set("@#{p}", nil)
                else
                    instance_variable_set("@#{p}", params_init[p])
                end
            end

            # Yield self for configuration by a block.
            yield self

            # Raise a ConfigError if any of the parameters are unset.
            params.each do |p|
                if instance_variable_get("@#{p}").nil?
                    raise ConfigError, "The #{p} parameter of a #{self.class.name} configuration object must be set."
                end
            end

            @initialized = true
        end

        # This allows some metaprogramming magic to allow the user to set instance variables
        # (config parameters) while initializing the configuration object, but ensures
        # that these parameters are readonly once the object is initialized.
        def method_missing(m, *args, &block)
            params.each do |v|
                # We don't allow the setting of instance variables if the object
                # has been initialized.
                if !@initialized && m == "#{v}=".to_sym
                    instance_variable_set("@#{v}", args[0])
                    return
                elsif m == "#{v}".to_sym
                    return instance_variable_get("@#{v}")
                end
            end
            
            # Otherwise just call super's method_missing
            super
        end
    end

    # Configuration object.
    #
    # An object which represents the configuration of a Zemu emulator.
    class Config
        # Memory object.
        #
        # This is an abstract class from which all other memory objects inherit.
        class Memory < ConfigObject
            # Constructor.
            #
            # Do not use, as this is an abstract class. Use one of the subclasses instead.
            def initialize
                super
            end

            # @return [Boolean] true if this memory section is readonly, false otherwise.
            def readonly?
                return false
            end

            # Valid parameters for this object.
            # Should be extended by subclasses but NOT REPLACED.
            def params
                return %w(name address size)
            end
        end

        # Read-Only Memory object
        #
        # Represents a block of memory which is read-only.
        class ROM < Memory
            # Constructor.
            #
            # Takes a block in which the parameters of the memory block
            # can be initialized.
            #
            # All parameters can be set within this block.
            # They become readonly as soon as the block completes.
            #
            # @example
            #   
            #   Zemu::Config::ROM.new do |m|
            #       m.address = 0x8000
            #       m.size = 256
            #   end
            #
            #
            def initialize
                super
            end

            def readonly?
                return true
            end
        end

        # The name of the configuration.
        # This will also be the name of the generated executable
        # when the emulator is built.
        attr_reader :name

        # The path to the compiler to use when building.
        # By default this is +clang+, with no path reference.
        attr_reader :compiler

        # The memory sections of this configuration object.
        attr_reader :memory

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

            @memory = []

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

        # Adds a new memory section to this configuration.
        #
        # @param [Zemu::Config::Memory] mem The memory object to add.
        def add_memory(mem)
            @memory << mem
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

            %w(name compiler).each do |v|
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