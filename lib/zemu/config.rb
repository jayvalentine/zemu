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
    #
    # @param [String] name The name of the configuration.
    # @param [String] compiler The path to the compiler to be used for compiling the emulator executable.
    #
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

            # Gets or sets an array of bytes representing the initial state
            # of this memory block.
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

            # Reads the contents of a file in binary format and
            # returns them as an array.
            def from_binary(file)
                return File.open(file, "rb") do |f|
                    bin = []

                    f.each_byte { |b| bin << b }

                    bin
                end
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
            #   Zemu::Config::ROM.new do
            #       address 0x8000
            #       size 256
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

        # Random-access Memory object
        #
        # Represents a block of memory which can be read and written.
        class RAM < Memory
        end

        # Input/Output Port object
        #
        # Represents an input/output device assigned to one or more ports.
        class IOPort < ConfigObject
            attr_reader :io_type

            # Constructor.
            #
            # Do not use, as this is an abstract class. Use one of the subclasses instead.
            def initialize
                if self.class == Zemu::Config::IOPort
                    raise NotImplementedError, "Cannot construct an instance of the abstract class Zemu::Config::IOPort."
                end

                @ports = []

                super
            end

            # Defines the setup behaviour of this IO device.
            #
            # Expects a block, the return value of which is a string
            # containing all data and function declarations required by this IO device.
            #
            # The block will be instance-evaluated at build-time, so it is possible to use
            # instance variables of the IO device.
            def when_setup(&block)
                @setup_block = block
            end

            # Defines the read behaviour of this IO device.
            #
            # Expects a block, the return value of which is a string
            # containing the behaviour of this IO device when a value is read from the IO bus.
            # Care must be taken to ensure that this functionality does not conflict with that of
            # any other IO devices.
            #
            # The block will be instance-evaluated at build-time, so it is possible to use
            # instance variables of the IO device.
            def when_read(&block)
                @read_block = block
            end

            # Defines the write behaviour of this IO device.
            #
            # Expects a block, the return value of which is a string
            # containing the behaviour of this IO device when a value is written to the IO bus.
            # Care must be taken to ensure that this functionality does not conflict with that of
            # any other IO devices.
            #
            # The block will be instance-evaluated at build-time, so it is possible to use
            # instance variables of the IO device.
            def when_write(&block)
                @write_block = block
            end

            # Evaluates the when_setup block of this IO device and returns the resulting string.
            def setup
                instance_eval(&@setup_block)
            end

            # Evaluates the when_read block of this IO device and returns the resulting string.
            def read
                instance_eval(&@read_block)
            end

            # Evaluates the when_write block of this IO device and returns the resulting string.
            def write
                instance_eval(&@write_block)
            end

            # Defines FFI API which will be available to the instance wrapper if this IO device is used.
            def functions
                [
                    {"name" => "zemu_io_#{name}_master_puts".to_sym, "args" => [:uint8], "return" => :void},
                    {"name" => "zemu_io_#{name}_master_gets".to_sym, "args" => [], "return" => :uint8},
                    {"name" => "zemu_io_#{name}_buffer_size".to_sym, "args" => [], "return" => :uint64}
                ]
            end

            # Valid parameters for this object.
            # Should be extended by subclasses but NOT REPLACED.
            def params
                %w(name)
            end
        end
        
        # Serial Input/Output object
        #
        # Represents a serial connection between the emulated CPU
        # and the host machine, with input and output mapped to Z80 I/O
        # ports.
        class SerialPort < IOPort
            # Constructor.
            #
            # Takes a block in which the parameters of the serial port
            # can be initialized.
            #
            # All parameters can be set within this block.
            # They become readonly as soon as the block completes.
            #
            # @example
            #   
            #   Zemu::Config::SerialPort.new do
            #       name "serial"
            #       in_port 0x00
            #       out_port 0x01
            #   end
            #
            #
            def initialize
                super

                when_setup do
                    "SerialBuffer io_#{name}_buffer_master = { .head = 0, .tail = 0 };\n" +
                    "SerialBuffer io_#{name}_buffer_slave = { .head = 0, .tail = 0 };\n" +
                    "\n" +
                    "zusize zemu_io_#{name}_buffer_size(void)\n" +
                    "{\n" +
                    "    zusize start = io_#{name}_buffer_slave.head;\n" +
                    "    zusize end = io_#{name}_buffer_slave.tail\n;" +
                    "    if (end < start) end += ZEMU_IO_SERIAL_BUFFER_SIZE;\n" +
                    "    return end - start;\n" +
                    "}\n" +
                    "\n" +
                    "void zemu_io_#{name}_slave_puts(zuint8 val)\n" +
                    "{\n" +
                    "    io_#{name}_buffer_slave.buffer[io_#{name}_buffer_slave.tail] = val;\n" +
                    "    io_#{name}_buffer_slave.tail++;\n" +
                    "    if (io_#{name}_buffer_slave.tail >= ZEMU_IO_SERIAL_BUFFER_SIZE)\n" +
                    "        io_#{name}_buffer_slave.tail = 0;\n" +
                    "}\n" +
                    "\n" +
                    "zuint8 zemu_io_#{name}_slave_gets(void)\n" +
                    "{\n" +
                    "    zuint8 val = io_#{name}_buffer_master.buffer[io_#{name}_buffer_master.head];\n" +
                    "    io_#{name}_buffer_master.head++;\n" +
                    "    if (io_#{name}_buffer_master.head >= ZEMU_IO_SERIAL_BUFFER_SIZE)\n" +
                    "        io_#{name}_buffer_master.head = 0;\n" +
                    "\n" +
                    "    return val;\n" +
                    "}\n" +
                    "\n" +
                    "void zemu_io_#{name}_master_puts(zuint8 val)\n" +
                    "{\n" +
                    "    io_#{name}_buffer_master.buffer[io_#{name}_buffer_master.tail] = val;\n" +
                    "    io_#{name}_buffer_master.tail++;\n" +
                    "    if (io_#{name}_buffer_master.tail >= ZEMU_IO_SERIAL_BUFFER_SIZE)\n" +
                    "        io_#{name}_buffer_master.tail = 0;\n" +
                    "}\n" +
                    "\n" +
                    "zuint8 zemu_io_#{name}_master_gets(void)\n" +
                    "{\n" +
                    "    zuint8 val = io_#{name}_buffer_slave.buffer[io_#{name}_buffer_slave.head];\n" +
                    "    io_#{name}_buffer_slave.head++;\n" +
                    "    if (io_#{name}_buffer_slave.head >= ZEMU_IO_SERIAL_BUFFER_SIZE)\n" +
                    "        io_#{name}_buffer_slave.head = 0;\n" +
                    "\n" +
                    "    return val;\n" +
                    "}\n"
                end

                when_read do
                    "if (port == #{in_port})\n" +
                    "{\n" +
                    "    return zemu_io_#{name}_slave_gets();\n" +
                    "}\n" +
                    "else if (port == #{ready_port})\n" +
                    "{\n" +
                    "    if (io_#{name}_buffer_master.head == io_#{name}_buffer_master.tail)\n" +
                    "    {\n" +
                    "        return 0;\n" +
                    "    }\n" +
                    "    else\n" +
                    "    {\n" +
                    "        return 1;\n" +
                    "    }\n" +
                    "}\n"
                end

                when_write do
                    "if (port == #{out_port})\n" +
                    "{\n" +
                    "    zemu_io_#{name}_slave_puts(value);\n" +
                    "}\n"
                end
            end

            # Valid parameters for a SerialPort, along with those
            # defined in [Zemu::Config::IOPort].
            def params
                super + %w(in_port out_port ready_port)
            end
        end

        # Gets a binding for this object.
        def get_binding
            return binding
        end

        # The memory sections of this configuration object.
        attr_reader :memory

        # The IO devices of this configuration object.
        attr_reader :io

        # Parameters accessible by this configuration object.
        def params
            return %w(name compiler output_directory clock_speed)
        end

        # Initial value for parameters of this configuration object.
        def params_init
            return {
                "compiler" => "clang",
                "output_directory" => "bin",
                "clock_speed" => 0
            }
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
        #   Zemu::Config.new do
        #       name "my_config"
        #
        #       add_memory Zemu::Config::ROM.new do
        #           name "rom"
        #           address 0x0000
        #           size 0x1000
        #       end
        #   end
        #
        # @raise [Zemu::ConfigError] Raised if the +name+ parameter is not set, or contains whitespace.
        def initialize
            @memory = []
            @io = []

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

        # Adds a new IO device to this configuration.
        #
        # @param [Zemu::Config::IOPort] io The IO device to add.
        def add_io(io)
            @io << io
        end
    end

    # Error raised when a configuration is initialized incorrectly.
    class ConfigError < StandardError
        def initialize(msg="The configuration is invalid.")
            super
        end
    end
end