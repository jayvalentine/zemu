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

        def initialize(&block)
            if self.class == Zemu::ConfigObject
                raise NotImplementedError, "Cannot construct an instance of the abstract class Zemu::ConfigObject."
            end

            @initialized = false

            # Initialize each parameter to nil
            params.each do |p|
                if params_init[p].nil?
                    instance_variable_set("@#{p}", nil)
                else
                    instance_variable_set("@#{p}", params_init[p])
                end
            end

            # Instance eval the block.
            instance_eval(&block)

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
                if m == "#{v}".to_sym
                    if args.size == 1 && !@initialized
                        instance_variable_set("@#{v}", args[0])
                        return
                    elsif args.size == 0
                        return instance_variable_get("@#{v}")
                    end
                end
            end
            
            # Otherwise just call super's method_missing
            super
        end
    end

    # Configuration object.
    #
    # An object which represents the configuration of a Zemu emulator.
    class Config < ConfigObject
        # Memory object.
        #
        # This is an abstract class from which all other memory objects inherit.
        class Memory < ConfigObject
            # Constructor.
            #
            # Do not use, as this is an abstract class. Use one of the subclasses instead.
            def initialize
                if self.class == Zemu::Config::Memory
                    raise NotImplementedError, "Cannot construct an instance of the abstract class Zemu::Config::Memory."
                end

                @contents = []

                super

                # Pad contents with 0x00 bytes.
                (@size - @contents.size).times do
                    @contents << 0x00
                end
            end

            def contents(*args)
                if args.size.zero?
                    return @contents
                else
                    @contents = args[0]
                end
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

        # The memory sections of this configuration object.
        attr_reader :memory

        def params
            return %w(name compiler)
        end

        def params_init
            return { "compiler" => "clang" }
        end

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
            @memory = []

            super

            if @name.empty?
                raise ConfigError, "The name parameter of a Zemu::Config configuration object cannot be empty."
            end

            if /\s/ =~ @name
                raise ConfigError, "The name parameter of a Zemu::Config configuration object cannot contain whitespace."
            end
        end

        # Adds a new memory section to this configuration.
        #
        # @param [Zemu::Config::Memory] mem The memory object to add.
        def add_memory(mem)
            @memory << mem
        end
    end

    class ConfigError < StandardError
        def initialize(msg="The configuration is invalid.")
            super
        end
    end
end