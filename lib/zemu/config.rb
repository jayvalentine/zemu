module Zemu
    # Configuration object.
    #
    # An object which represents the configuration of a Zemu emulator.
    class Config
        # Memory object.
        #
        # This is an abstract class from which all other memory objects inherit.
        class Memory
            # Name of the memory section.
            attr_reader :name

            # Address of the memory section.
            # This will be a value between 0x0000 and 0xFFFF.
            attr_reader :address

            # Size of the memory section.
            attr_reader :size

            # Constructor.
            #
            # Do not use, as this is an abstract class. Use one of the subclasses instead.
            def initialize
                raise NotImplementedError, "Cannot construct an instance of the abstract class Zemu::Config::Memory."
            end

            # @return [Boolean] true if this memory section is readonly, false otherwise.
            def readonly?
                return false
            end

            # Valid parameters for this object.
            # Should be extended by subclasses but NOT REPLACED.
            def params
                return ["address", "size", "name"]
            end
            
            private :params
            
            # This allows some metaprogramming magic to allow the user to set instance variables
            # (config parameters) while initializing the configuration object, but ensures
            # that these parameters are readonly once the object is initialized.
            def method_missing(m, *args, &block)
                # We don't allow the setting of instance variables if the object
                # has been initialized.
                if @initialized
                    super
                end
                
                params.each do |v|
                    if m == "#{v}=".to_sym
                        instance_variable_set("@#{v}", args[0])
                        return
                    end
                end
                
                # Otherwise just call super's method_missing
                super
            end
            
            private :method_missing
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
                @initialized = false

                @address = nil
                @size = nil
                @name = nil

                yield self

                if @address.nil?
                    raise ConfigError, "The address parameter of a Memory configuration object must be set."
                end

                if @size.nil?
                    raise ConfigError, "The size parameter of a Memory configuration object must be set."
                end

                if @name.nil?
                    raise ConfigError, "The name parameter of a Memory configuration object must be set."
                end

                @initialized = true
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