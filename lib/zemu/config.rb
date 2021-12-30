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

                @nmi = false

                super
            end

            # Setup to be performed on initialising the emulator
            # instance.
            def when_setup
                ""
            end

            # Memory bus write handler.
            #
            # Handles write access via the memory bus to this device.
            #
            # @param addr The address being accessed.
            # @param value The value being written.
            def mem_write(addr, value)
            end

            # Memory bus read handler.
            #
            # Handles read access via the memory bus to this device.
            #
            # @param addr The address being accessed.
            #
            # Returns the value read, or nil if no value
            # (e.g. if address falls outside range for this device).
            def mem_read(addr)
                nil
            end

            # IO bus write handler.
            #
            # Handles write access via the IO bus to this device.
            #
            # @param port The IO port being accessed.
            # @param value The value being written.
            def io_write(port, value)
            end

            # IO bus read handler.
            #
            # Handles read access via the IO bus to this device.
            #
            # @param port The IO port being accessed.
            #
            # Returns the value read from the port, or nil if no
            # value (e.g. port does not correspond to this device).
            def io_read(port)
                nil
            end

            # Clock handler.
            #
            # Handles a clock cycle for this device.
            # Deriving objects can use the nmi function
            # to set the state of the non-maskable interrupt
            # at each clock cycle.
            def clock
            end

            # FFI functions provided by this device.
            def functions
                []
            end

            # Sets state of the NMI for this device.
            def nmi(state)
                @nmi = state
            end

            # Gets state of NMI for this device.
            def nmi?
                @nmi
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

            # Memory bus read handler.
            #
            # Handles read access via the memory bus to this device.
            #
            # @param addr The address being accessed.
            #
            # Returns the value read, or nil if no value
            # (e.g. if address falls outside range for this device).
            def mem_read(addr)
                # Return value in memory's contents if the address
                # falls within range.
                if (addr >= address) && (addr < (address + size))
                    offset = addr - address
                    return @contents[offset]
                end

                # Otherwise return nil - address does not correspond
                # to this memory block.
                nil
            end

            # Memory bus write handler.
            #
            # Handles write access via the memory bus to this device.
            #
            # @param addr The address being accessed.
            # @param value The value being written.
            def mem_write(addr, value)
                # If address falls within range, set value in
                # memory contents.
                if (addr >= address) && (addr < (address + size))
                    offset = addr - address
                    @contents[offset] = value
                end
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

            # Memory write handler.
            def mem_write(addr, port)
                # Does nothing - cannot write to read-only memory.
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

                @buffer_tx = []
                @buffer_rx = []
            end

            # IO bus read handler.
            #
            # Handles read access via the IO bus to this device.
            #
            # @param port The IO port being accessed.
            #
            # Returns the value read, or nil if the port does not
            # correspond to this device.
            def io_read(port)
                if port == in_port
                    return @buffer_rx.shift()
                elsif port == ready_port
                    if @buffer_rx.empty?
                        return 0
                    else
                        return 1
                    end
                end

                nil
            end

            # IO bus write handler.
            #
            # Handles write access via the IO bus to this device.
            #
            # @param port The IO port being accessed.
            # @param value The value being written.
            def io_write(port, value)
                if port == out_port
                    @buffer_tx << value
                end
            end

            # Gets number of bytes transmitted by the CPU,
            # but not yet read from this device.
            def transmitted_count
                @buffer_tx.size
            end

            # Gets a byte transmitted by the CPU, or nil
            # if transmit buffer is empty.
            def get_byte
                @buffer_tx.shift()
            end

            # Puts a byte in the receive buffer of this device.
            def put_byte(b)
                @buffer_rx << b
            end

            # Puts a string in the receive buffer of this device.
            def puts(s)
                s.each_byte { |b| put_byte(b) }
            end

            # Gets a string from the transmit buffer of this device.
            # String length will be no more than n, but may be less
            # if fewer characters exist in buffer.
            #
            # @param n Length of string to retrieve. If omitted the
            # entire buffer will be returned.
            def gets(n=nil)
                s = ""

                if n.nil?
                    until (c = get_byte()).nil?
                        s += c.chr
                    end
                else
                    n.times do
                        c = get_byte()
                        break if c.nil?

                        s += c.chr
                    end
                end

                s
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
            # Mode for reading drive.
            DRIVE_MODE_READ = 0x01

            # Mode for writing drive.
            DRIVE_MODE_WRITE = 0x02

            # Uninitialised drive mode.
            DRIVE_MODE_UNINIT = 0x00

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

                @lba_0 = 0
                @lba_1 = 0
                @lba_2 = 0
                @lba_3 = 0

                @drive_mode = DRIVE_MODE_UNINIT
                @drive_status = 0b01000000
                @sector_offset = 0
                @sector_data = []
            end

            # IO bus read handler.
            #
            # Handles read access via the IO bus to this device.
            #
            # @param port The IO port being accessed.
            #
            # Returns the value read, or nil if the port does not
            # correspond to this device.
            def io_read(port)
                if port == base_port
                    b = @sector_data.shift()

                    if @sector_data.empty?
                        @drive_status = 0b01000000
                    end

                    return b
                elsif port == (base_port + 7)
                    return @drive_status
                end

                nil
            end

            def get_sector()
                sector = 0
                sector |= @lba_0
                sector |= @lba_1 << 8
                sector |= @lba_2 << 16
                sector |= @lba_3 << 24

                sector
            end

            def write_current_sector()
                file_offset = get_sector() * sector_size
                File.open(@initialize_from, "r+b") do |f|
                    f.seek(file_offset)
                    f.write(@sector_data.pack("C" * sector_size))
                end
            end

            def load_sector()
                file_offset = get_sector() * sector_size
                File.open(@initialize_from, "rb") do |f|
                    f.seek(file_offset)
                    s = f.read(sector_size)
                    @sector_data = s.unpack("C" * sector_size)
                end
            end

            # IO bus write handler.
            #
            # Handles write access via the IO bus to this device.
            #
            # @param port The IO port being accessed.
            # @param value The value being written.
            def io_write(port, value)
                if port == base_port
                    if @drive_mode == DRIVE_MODE_WRITE
                        @sector_data << value
                        if @sector_data.size >= sector_size
                            write_current_sector()
                            @drive_status = 0b01000000
                        end
                    end
                elsif port == (base_port + 3)
                    @lba_0 = (value & 0xff)
                elsif port == (base_port + 4)
                    @lba_1 = (value & 0xff)
                elsif port == (base_port + 5)
                    @lba_2 = (value & 0xff)
                elsif port == (base_port + 6)
                    @lba_3 = (value & 0x1f)
                elsif port == (base_port + 7)
                    # Read command.
                    if value == 0x20
                        load_sector()

                        @drive_mode = DRIVE_MODE_READ
                        @drive_status = 0b00001000

                    # Write command.
                    elsif value == 0x30
                        @sector_data = []

                        @drive_mode = DRIVE_MODE_WRITE
                        @drive_status = 0b00001000
                    end
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

            # Read a byte at the given offset in a sector.
            #
            # @param sector The sector to read from.
            # @param offset Offset in that sector to read.
            #
            # Returns the byte read from the file.
            def read_byte(sector, offset)
                file_offset = (sector * sector_size) + offset
                File.open(@initialize_from, "rb") do |f|
                    f.seek(file_offset)
                    s = f.read(1)
                    return s.unpack("C")[0]
                end
            end

            # Defines FFI API which will be available to the instance wrapper if this IO device is used.
            def functions
                [
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
            RUNNING = 0x01
            STOPPED = 0x00

            def initialize
                super

                @count = 0
                @running = false
            end
            
            # IO bus write handler.
            #
            # Handles write access via the IO bus to this device.
            #
            # @param port The IO port being accessed.
            # @param value The value being written.
            def io_write(port, value)
                if port == count_port
                    @count = value
                elsif port == control_port
                    @running = if value == 0 then STOPPED else RUNNING end
                end
            end

            # Clock handler.
            #
            # Handles a clock cycle for this device.
            # Sets NMI active if the count reaches 0.
            def clock
                if @running == RUNNING
                    if @count > 0
                        @count -= 1
                    else
                        nmi(true)
                    end
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