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
        #
        # This is an abstract class and cannot be instantiated directly.
        # The when_setup, when_read, and when_write methods can be used to define
        # the behaviour of a subclass.
        #
        # @example
        #    class MyIODevice < IOPort
        #        # Extend the parameters of the object so we can define a port.
        #        def params
        #            super + "port"
        #        end
        #
        #        def initialize
        #            super
        # 
        #            # Define the setup for the IO device.
        #            # This is some global C code that ends up in "io.c".
        #            # Parameters can be used here, as the block is instance-evaluated.
        #            when_setup do
        #                %Q(zuint8 #{name}_value = 42;)
        #            end
        #
        #            # Define the logic when reading from an IO port.
        #            # The C variable "port" takes the value of the 8-bit port
        #            # address being read from, and should be used to identify
        #            # if this IO device is the one being used.
        #            when_read do
        #                %Q(if (port == #{port}) return #{name}_value;)
        #            end
        #
        #            # Define the logic when writing to the IO port.
        #            # Similar to #when_read, but we have access to an extra
        #            # C variable, "value". This is the value being written
        #            # to the IO port.
        #            when_write do
        #                %Q(if (port == #{port}) #{name}_value = value;)
        #            end
        #        end
        #    end
        #
        #    # The subclass can now be declared as below:
        #    device = MyIODevice.new do
        #        name "myDevice"
        #        port 11
        #    end
        #
        #
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
                @setup_block = nil
                @read_block = nil
                @write_block = nil
                @clock_block = nil

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

            # Defines the per-cycle behaviour of this IO device.
            #
            # Expects a block, the return value of which is a string
            # defining the behaviour of the IO device on each system clock cycle.
            # Care must be taken to ensure that this functionality does not conflict with that of
            # any other IO devices.
            #
            # The block will be instance-evaluated at build-time, so it is possible to use
            # instance variables of the IO device.
            def when_clock(&block)
                @clock_block = block
            end

            # Evaluates the when_setup block of this IO device and returns the resulting string.
            def setup
                return instance_eval(&@setup_block) unless @setup_block.nil?
                return ""
            end

            # Evaluates the when_read block of this IO device and returns the resulting string.
            def read
                return instance_eval(&@read_block) unless @read_block.nil?
                return ""
            end

            # Evaluates the when_write block of this IO device and returns the resulting string.
            def write
                return instance_eval(&@write_block) unless @write_block.nil?
                return ""
            end

            # Evaluates the when_clock block of this IO device and returns the resulting string.
            def clock
                return instance_eval(&@clock_block) unless @clock_block.nil?
                return ""
            end

            # Defines FFI API which will be available to the instance wrapper if this IO device is used.
            def functions
                []
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

            # Defines FFI API which will be available to the instance wrapper if this IO device is used.
            def functions
                [
                    {"name" => "zemu_io_#{name}_master_puts".to_sym, "args" => [:uint8], "return" => :void},
                    {"name" => "zemu_io_#{name}_master_gets".to_sym, "args" => [], "return" => :uint8},
                    {"name" => "zemu_io_#{name}_buffer_size".to_sym, "args" => [], "return" => :uint64}
                ]
            end

            # Valid parameters for a SerialPort, along with those
            # defined in [Zemu::Config::IOPort].
            def params
                super + %w(in_port out_port ready_port)
            end
        end

        # Block drive object
        #
        # Represents a device with a sequence of sectors of a fixed size,
        # which can be accessed via IO instructions as an IDE drive.
        class BlockDrive < IOPort
            # Constructor.
            #
            # Takes a block in which the parameters of the block drive
            # can be initialized.
            #
            # All parameters can be set within this block.
            # They become readonly as soon as the block completes.
            #
            # Constructor raises RangeError if a file is provided for initialization
            # and it is of the wrong size.
            #
            # @example
            #   
            #   Zemu::Config::BlockDrive.new do
            #       name "drive"
            #       base_port 0x0c
            #       sector_size 512
            #       num_sectors 64
            #   end
            #
            #
            def initialize
                @initialize_from = nil

                super
                
                # Initialize from provided file if applicable.
                unless @initialize_from.nil?
                    # Check file size.
                    file_size = File.size(@initialize_from)
                    if (file_size != num_sectors * sector_size)
                        raise RangeError, "Initialization file for Zemu::Config::BlockDrive '#{name}' is of wrong size."
                    end
                end

                when_setup do
<<-eos
#include <stdio.h>

zuint8 sector_data_#{name}[#{sector_size}];
zuint32 sector_data_#{name}_offset;
zuint32 loaded_sector_#{name} = Z_UINT32_MAXIMUM;
zuint8 drive_mode_#{name};
zuint8 drive_status_#{name} = 0b01000000;

zuint8 lba_#{name}_0;
zuint8 lba_#{name}_1;
zuint8 lba_#{name}_2;
zuint8 lba_#{name}_3;

void internal_#{name}_load_sector(zuint32 sector)
{
    if (loaded_sector_#{name} == sector) return;

    FILE * fptr = fopen("#{@initialize_from}", "rb");
    fseek(fptr, sector * #{sector_size}, SEEK_SET);
    fread(sector_data_#{name}, #{sector_size}, 1, fptr);
    fclose(fptr);

    loaded_sector_#{name} = sector;
}

void internal_#{name}_write_current_sector()
{
    FILE * fptr = fopen("#{@initialize_from}", "r+b");
    fseek(fptr, loaded_sector_#{name} * #{sector_size}, SEEK_SET);
    fwrite(sector_data_#{name}, 1, #{sector_size}, fptr);
    fclose(fptr);
}

zuint8 zemu_io_#{name}_readbyte(zuint32 sector, zuint32 offset)
{
    internal_#{name}_load_sector(sector);
    return sector_data_#{name}[offset];
}
eos
                end

                when_read do
<<-eos
if (port == #{base_port})
{
    zuint8 b = sector_data_#{name}[sector_data_#{name}_offset];
    sector_data_#{name}_offset++;
    if (sector_data_#{name}_offset >= #{sector_size})
    {
        drive_status_#{name} = 0b01000000;
    }
    return b;
}
else if (port == #{base_port+7})
{
    return drive_status_#{name};
}
eos
                end

                when_write do
<<-eos
if (port == #{base_port})
{
    if (drive_mode_#{name} == 0x01)
    {
        sector_data_#{name}[sector_data_#{name}_offset] = value;
        sector_data_#{name}_offset++;
        if (sector_data_#{name}_offset >= #{sector_size})
        {
            internal_#{name}_write_current_sector();
            drive_status_#{name} = 0b01000000;
        }
    }
}
else if (port == #{base_port+3})
{
    lba_#{name}_0 = value;
}
else if (port == #{base_port+4})
{
    lba_#{name}_1 = value;
}
else if (port == #{base_port+5})
{
    lba_#{name}_2 = value;
}
else if (port == #{base_port+6})
{
    lba_#{name}_3 = value & 0b00011111;
}
else if (port == #{base_port+7})
{
    if (value == 0x20)
    {
        zuint32 sector = 0;
        sector |= (zuint32)lba_#{name}_3 << 24;
        sector |= (zuint32)lba_#{name}_2 << 16;
        sector |= (zuint32)lba_#{name}_1 << 8;
        sector |= (zuint32)lba_#{name}_0;

        internal_#{name}_load_sector(sector);
        sector_data_#{name}_offset = 0;

        drive_mode_#{name} = 0x00;
        drive_status_#{name} = 0b00001000;
    }
    else if (value == 0x30)
    {
        zuint32 sector = 0;
        sector |= (zuint32)lba_#{name}_3 << 24;
        sector |= (zuint32)lba_#{name}_2 << 16;
        sector |= (zuint32)lba_#{name}_1 << 8;
        sector |= (zuint32)lba_#{name}_0;

        internal_#{name}_load_sector(sector);
        sector_data_#{name}_offset = 0;

        drive_mode_#{name} = 0x01;
        drive_status_#{name} = 0b00001000;
    }
}
eos
                end
            end

            # Array of sectors of this drive.
            def blocks
                b = []
                
                if @initialize_from.nil?
                    num_sectors.times do
                        this_block = []
                        sector_size.times do
                            this_block << 0
                        end
                        b << this_block
                    end
                    return b
                end
                
                File.open(@initialize_from, "rb") do |f|
                    num_sectors.times do
                        this_block = f.read(sector_size)
                        b << this_block.unpack("C" * sector_size)
                    end
                end

                b
            end

            # Set file to initialize from.
            def initialize_from(file)
                @initialize_from = file
            end

            # Defines FFI API which will be available to the instance wrapper if this IO device is used.
            def functions
                [
                    {"name" => "zemu_io_#{name}_readbyte", "args" => [:uint32, :uint32], "return" => :uint8},
                ]
            end

            # Valid parameters for a BlockDrive, along with those
            # defined in [Zemu::Config::IOPort].
            def params
                super + %w(base_port sector_size num_sectors)
            end
        end

        # Non-Maskable Interrupt Timer
        #
        # Represents a timer device, the period of which can be controlled
        # by the CPU through an IO port. The timer generates an NMI once this
        # period has expired. The timer can be reset via a control port.
        class Timer < IOPort
            def initialize
                super

                when_setup do
                    "zuint8 io_#{name}_count;\n" +
                    "zuint8 io_#{name}_running = 0;\n"
                end

                when_read do
                end

                when_write do
                    "if (port == #{count_port}) io_#{name}_count = value;\n" +
                    "else if (port == #{control_port}) io_#{name}_running = value;\n"
                end

                when_clock do
                    "if (io_#{name}_running)\n" +
                    "{\n" +
                    "    if (io_#{name}_count > 0) io_#{name}_count--;\n" +
                    "    else zemu_io_nmi(instance);\n" +
                    "}\n"
                end
            end

            # Valid parameters for a Timer, along with those defined in
            # [Zemu::Config::IOPort].
            def params
                super + %w(count_port control_port)
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
            return %w(name compiler output_directory clock_speed serial_delay)
        end

        # Initial value for parameters of this configuration object.
        def params_init
            return {
                "compiler" => "clang",
                "output_directory" => "bin",
                "clock_speed" => 0,
                "serial_delay" => 0
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