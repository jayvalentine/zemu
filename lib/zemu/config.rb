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
        # Bus Device.
        #
        # Represents a device connected to the I/O
        # or memory buses, or both.
        class BusDevice < ConfigObject
            # Constructor.
            #
            # This object should not be constructed directly.
            def initialize
                if self.class == Zemu::Config::BusDevice
                    raise NotImplementedError, "Cannot construct an instance of the abstract class Zemu::Config::BusDevice."
                end

                super
            end

            # Setup to be performed on initialising the emulator
            # instance.
            def when_setup
                ""
            end

            # Memory bus write handler.
            #
            # Defines C code generated for handling memory
            # writes for this device.
            def when_mem_write
                ""
            end

            # Memory bus read handler.
            #
            # Defines C code generated for handling memory
            # reads for this device.
            def when_mem_read
                ""
            end

            # IO bus write handler.
            #
            # Defines C code generated for handling IO
            # writes for this device.
            def when_io_write
                ""
            end

            # IO bus read handler.
            #
            # Defines C code generated for handling IO
            # reads for this device.
            def when_io_read
                ""
            end

            # Clock handler.
            #
            # Defines C code which executes for every
            # clock cycle.
            def when_clock
                ""
            end

            # FFI functions provided by this device.
            def functions
                []
            end

            # Parameters for a bus device.
            def params
                %w(name)
            end
        end

        # Memory object.
        #
        # This is an abstract class from which all other memory objects inherit.
        class Memory < BusDevice
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

            # Is this memory read-only?
            def readonly?
                false
            end

            # Defines generated C to declare this memory block.
            def when_setup
                init_array = []
                contents.each_with_index do |b, i|
                    init_array << ((i % 16 == 0) ? "\n    " : "") + ("0x%02x, " % b)
                end

<<-eos
/* Initialization memory block "#{name}" */
#{if self.readonly? then "const" else "" end} zuint8 zemu_memory_block_#{name}[0x#{size.to_s(16)}] =
{#{init_array.join("")}
};
eos
            end

            # Defines generated C to handle reading this memory block.
            def when_mem_read
<<-eos
if (address_32 >= 0x#{address.to_s(16)} && address_32 < 0x#{(address + size).to_s(16)})
{
    return zemu_memory_block_#{name}[address_32 - 0x#{address.to_s(16)}];
}
eos
            end

            # Defines generated C to handle writing to this memory block.
            def when_mem_write
<<-eos
if (address_32 >= 0x#{address.to_s(16)} && address_32 < 0x#{(address + size).to_s(16)})
{
    zemu_memory_block_#{name}[address_32 - 0x#{address.to_s(16)}] = value;
}
eos
            end

            # Valid parameters for this object.
            # Should be extended by subclasses but NOT REPLACED.
            def params
                super + %w(address size)
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

            # Is this memory block readonly?
            def readonly?
                true
            end

            # Defines generated C to handle writing to this
            # memory block. Because this block is read-only,
            # no code is generated to handle writes.
            def when_mem_write
                # Cannot write to read-only memory.
                ""
            end
        end

        # Random-access Memory object
        #
        # Represents a block of memory which can be read and written.
        class RAM < Memory
        end
        
        # Serial Input/Output object
        #
        # Represents a serial connection between the emulated CPU
        # and the host machine, with input and output mapped to Z80 I/O
        # ports.
        class SerialPort < BusDevice
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
            end

            # Defines generated C to declare the serial device.
            def when_setup
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

            # Defines generated C to handle reading from serial port's
            # registers.
            def when_io_read
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

            # Defines generated C to handle writing to the serial port's registers.
            def when_io_write
                "if (port == #{out_port})\n" +
                "{\n" +
                "    zemu_io_#{name}_slave_puts(value);\n" +
                "}\n"
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
            # defined in [Zemu::Config::BusDevice].
            def params
                super + %w(in_port out_port ready_port)
            end
        end

        # Block drive object
        #
        # Represents a device with a sequence of sectors of a fixed size,
        # which can be accessed via IO instructions as an IDE drive.
        class BlockDrive < BusDevice
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
            end

            # Defines generated C to declare the block device.
            def when_setup
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

            # Defines generated C to handle reading the block drive's
            # registers.
            def when_io_read
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

            # Defines generated C to handle writing to the block drive's
            # registers.
            def when_io_write
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
            # defined in [Zemu::Config::BusDevice].
            def params
                super + %w(base_port sector_size num_sectors)
            end
        end

        # Non-Maskable Interrupt Timer
        #
        # Represents a timer device, the period of which can be controlled
        # by the CPU through an IO port. The timer generates an NMI once this
        # period has expired. The timer can be reset via a control port.
        class Timer < BusDevice
            # Defines generated C that sets up the timer.
            def when_setup
                "zuint8 io_#{name}_count;\n" +
                "zuint8 io_#{name}_running = 0;\n"
            end

            # Defines generated C that handles writing to the timer's
            # registers.
            def when_io_write
                "if (port == #{count_port}) io_#{name}_count = value;\n" +
                "else if (port == #{control_port}) io_#{name}_running = value;\n"
            end

            # Defines generated C that handles a clock tick for the timer.
            def when_clock
                "if (io_#{name}_running)\n" +
                "{\n" +
                "    if (io_#{name}_count > 0) io_#{name}_count--;\n" +
                "    else zemu_io_nmi(instance);\n" +
                "}\n"
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

        # The bus devices of this configuration object.
        attr_reader :devices

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
            @devices = []

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
        # Deprecated - retained only for backwards compatibility.
        # Use add_device instead.
        #
        # @param [Zemu::Config::Memory] mem The memory object to add.
        def add_memory(mem)
            @devices << mem
        end

        # Adds a new IO device to this configuration.
        #
        # Deprecated - retained only for backwards compatibility.
        # Use add_device instead.
        #
        # @param [Zemu::Config::BusDevice] io The IO device to add.
        def add_io(io)
            @devices << io
        end

        # Adds a new device to the bus for this configuration.
        #
        # @param [Zemu::Config::BusDevice] device The device to add.
        def add_device(device)
            @devices << device
        end
    end

    # Error raised when a configuration is initialized incorrectly.
    class ConfigError < StandardError
        def initialize(msg="The configuration is invalid.")
            super
        end
    end
end