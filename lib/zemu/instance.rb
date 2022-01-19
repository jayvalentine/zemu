require 'ffi'
require 'ostruct'

module Zemu
    # Represents an instance of a Zemu emulator.
    #
    # Provides methods by which the state of the emulator can be observed
    # and the execution of the program controlled.
    class Instance
        # Mapping of register names to the ID numbers used to identify them
        # by the debug functionality of the built library.
        REGISTERS = {
            # Special purpose registers
            "PC" => 0,
            "SP" => 1,
            "IY" => 2,
            "IX" => 3,

            # Main register set
            "A" => 4,
            "F" => 5,
            "B" => 6,
            "C" => 7,
            "D" => 8,
            "E" => 9,
            "H" => 10,
            "L" => 11,

            # Alternate register set
            "A'" => 12,
            "F'" => 13,
            "B'" => 14,
            "C'" => 15,
            "D'" => 16,
            "E'" => 17,
            "H'" => 18,
            "L'" => 19
        }

        # Mapping of extended registers
        # to the registers that comprise them.
        REGISTERS_EXTENDED = {
            "HL" => ["H", "L"],
            "BC" => ["B", "C"],
            "DE" => ["D", "E"]
        }

        # States that the emulated machine can be in.
        class RunState
            # Currently executing an instruction.
            RUNNING = 0

            # Executed a HALT instruction in the previous cycle.
            HALTED = 1

            # Hit a breakpoint in the previous cycle.
            BREAK = 2

            # Undefined. Emulated machine has not yet reached a well-defined state.
            UNDEFINED = -1
        end

        attr_reader :trace

        def initialize(configuration)
            @trace = []

            @devices = configuration.devices

            # Methods defined by bus devices that we make
            # accessible to the user.
            @device_methods = []

            @clock = configuration.clock_speed
            @serial_delay = configuration.serial_delay

            @wrapper = make_wrapper(configuration)

            @serial = []

            @instance = @wrapper.zemu_init

            # Declare handlers.
            # Memory write handler.
            @mem_write = Proc.new do |addr, value|
                @devices.each do |d|
                    d.mem_write(addr, value)
                end
            end

            # Memory read handler.
            @mem_read = Proc.new do |addr|
                r = 0
                @devices.each do |d|
                    v = d.mem_read(addr)
                    unless v.nil?
                        r = v
                        break
                    end
                end

                r
            end

            # IO write handler.
            @io_write = Proc.new do |port, value|
                @devices.each do |d|
                    d.io_write(port, value)
                end
            end

            # IO read handler.
            @io_read = Proc.new do |port|
                r = 0
                @devices.each do |d|
                    v = d.io_read(port)
                    unless v.nil?
                        r = v
                        break
                    end
                end

                r
            end

            # IO read handler.
            @io_clock = Proc.new do |cycles|
                @devices.each do |d|
                    d.clock(cycles)
                end

                bus_state = 0

                if @devices.any? { |d| d.nmi? }
                    bus_state |= 1
                end

                if @devices.any? { |d| d.interrupt? }
                    bus_state |= 2
                end

                bus_state
            end

            # Attach handlers.
            @wrapper.zemu_set_mem_write_handler(@mem_write)
            @wrapper.zemu_set_mem_read_handler(@mem_read)
            @wrapper.zemu_set_io_write_handler(@io_write)
            @wrapper.zemu_set_io_read_handler(@io_read)
            @wrapper.zemu_set_io_clock_handler(@io_clock)

            @wrapper.zemu_power_on(@instance)
            @wrapper.zemu_reset(@instance)

            @state = RunState::UNDEFINED

            @breakpoints = {}
        end

        # Returns the device with the given name, or nil
        # if no such device exists.
        def device(name)
            @devices.each do |d|
                if d.name == name
                    return d
                end
            end

            nil
        end

        # Returns the clock speed of this instance in Hz.
        def clock_speed
            return @clock
        end

        # Returns the delay between characters on the serial port for this instance in seconds.
        def serial_delay
            return @serial_delay
        end

        # Returns a hash containing current values of the emulated
        # machine's registers. All names are as those given in the Z80
        # reference manual.
        #
        # 16-bit general-purpose registers must be accessed by their 8-bit
        # component registers.
        def registers
            r = {}

            REGISTERS.each do |reg, num|
                r[reg] = @wrapper.zemu_debug_register(@instance, num)
            end

            REGISTERS_EXTENDED.each do |reg, components|
                hi = components[0]
                lo = components[1]
                r[reg] = (r[hi] << 8) | r[lo]
            end
            
            return r
        end

        # Access the value in memory at a given address.
        #
        # @param address The address in memory to be accessed.
        #
        # Returns 0 if the memory address is not mapped, otherwise
        # returns the value in the given memory location.
        def memory(address)
            return @wrapper.zemu_debug_get_memory(address)
        end

        # Set the value in memory at a given address.
        #
        # @param address The address in memory to be set.
        # @param value The value to set to.
        #
        # Returns nothing.
        def set_memory(address, value)
            @wrapper.zemu_debug_set_memory(address, value)
        end

        # Write a string to the serial line of the emulated CPU.
        #
        # @param string The string to be sent.
        #
        # Sends each character in the string to the receive buffer of the
        # emulated machine.
        def serial_puts(string)
            string.each_char do |c|
                device('serial').put_byte(c.ord)
            end
        end

        # Get a number of characters from the serial line of the emulated CPU.
        #
        # @param count The number of characters to get, or nil if all characters in the buffer
        #              should be retrieved.
        #
        # Gets the given number of characters from the emulated machine's send buffer.
        #
        # Note: If count is greater than the number of characters currently in the buffer,
        # the returned string will be shorter than the given count.
        def serial_gets(count=nil)
            return_string = ""

            actual_count = device('serial').transmitted_count()

            if count.nil? || actual_count < count
                count = actual_count
            end

            count.to_i.times do
                return_string += device('serial').get_byte().chr
            end

            return return_string
        end

        # Get a byte from the attached disk drive.
        #
        # @param sector The sector to read
        # @param offset The offset in sector to read
        #
        # Gets a byte at the given offset in the given sector.
        def drive_readbyte(sector, offset)
            return @wrapper.zemu_io_block_drive_readbyte(sector, offset)
        end

        # Continue running this instance until either:
        # * A HALT instruction is executed
        # * A breakpoint is hit
        # * The number of cycles given has been executed
        #
        # Returns the number of cycles executed.
        def continue(run_cycles=-1)
            # Return immediately if we're HALTED.
            return if @state == RunState::HALTED

            cycles_executed = 0

            @state = RunState::RUNNING

            # Run as long as:
            #   We haven't hit a breakpoint
            #   We haven't halted
            #   We haven't hit the number of cycles we've been told to execute for.
            while (run_cycles == -1 || cycles_executed < run_cycles) && (@state == RunState::RUNNING)
                cycles_executed += @wrapper.zemu_debug_step(@instance)

                pc = @wrapper.zemu_debug_pc(@instance)

                # If the PC is now pointing to one of our breakpoints,
                # we're in the BREAK state.
                if @breakpoints[pc]
                    @state = RunState::BREAK
                elsif @wrapper.zemu_debug_halted()
                    @state = RunState::HALTED
                end
            end

            return cycles_executed
        end

        # Set a breakpoint of the given type at the given address.
        #
        # @param address The address of the breakpoint
        # @param type The type of breakpoint:
        #   * :program => Break when the program counter hits the address given. 
        def break(address, type)
            @breakpoints[address] = true
        end

        # Remove a breakpoint of the given type at the given address.
        # Does nothing if no breakpoint previously existed at that address.
        #
        # @param address The address of the breakpoint to be removed.
        # @param type The type of breakpoint. See Instance#break.
        def remove_break(address, type)
            @breakpoints[address] = false
        end

        # Returns true if the CPU has halted, false otherwise.
        def halted?
            return @state == RunState::HALTED
        end

        # Returns true if a breakpoint has been hit, false otherwise.
        def break?
            return @state == RunState::BREAK
        end

        # Powers off the emulated CPU and destroys this instance.
        def quit
            @wrapper.zemu_power_off(@instance)
            @wrapper.zemu_free(@instance)
        end

        # Creates a wrapper around the Zemu module built with the given configuration.
        def make_wrapper(configuration)
            wrapper = Module.new

            wrapper.extend FFI::Library

            wrapper.ffi_lib [File.join(configuration.output_directory, "#{configuration.name}.so")]

            # Handler types for handling bus accesses.
            wrapper.callback :mem_write_handler, [:uint32, :uint8], :void
            wrapper.callback :mem_read_handler, [:uint32], :uint8

            wrapper.callback :io_write_handler, [:uint8, :uint8], :void
            wrapper.callback :io_read_handler, [:uint8], :uint8
            wrapper.callback :io_clock_handler, [:uint64], :uint8

            wrapper.attach_function :zemu_set_mem_write_handler, [:mem_write_handler], :void
            wrapper.attach_function :zemu_set_mem_read_handler, [:mem_read_handler], :void

            wrapper.attach_function :zemu_set_io_write_handler, [:io_write_handler], :void
            wrapper.attach_function :zemu_set_io_read_handler, [:io_read_handler], :void
            wrapper.attach_function :zemu_set_io_clock_handler, [:io_clock_handler], :void

            wrapper.attach_function :zemu_init, [], :pointer
            wrapper.attach_function :zemu_free, [:pointer], :void

            wrapper.attach_function :zemu_power_on, [:pointer], :void
            wrapper.attach_function :zemu_power_off, [:pointer], :void

            wrapper.attach_function :zemu_reset, [:pointer], :void

            wrapper.attach_function :zemu_debug_step, [:pointer], :uint64

            wrapper.attach_function :zemu_debug_halted, [], :bool

            wrapper.attach_function :zemu_debug_register, [:pointer, :uint16], :uint16
            wrapper.attach_function :zemu_debug_pc, [:pointer], :uint16

            wrapper.attach_function :zemu_debug_get_memory, [:uint16], :uint8
            wrapper.attach_function :zemu_debug_set_memory, [:uint16, :uint8], :void

            configuration.devices.each do |device|
                device.functions.each do |f|
                    wrapper.attach_function(f["name"].to_sym, f["args"], f["return"])
                    @device_methods << f["name"].to_sym
                end
            end

            return wrapper
        end

        # Redirects calls to I/O FFI functions.
        def method_missing(method, *args)
            if @device_methods.include? method
                return @wrapper.send(method)
            end

            super
        end

        private :make_wrapper
    end
end
