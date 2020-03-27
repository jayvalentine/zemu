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

        def initialize(configuration)
            @clock = configuration.clock_speed

            @wrapper = make_wrapper(configuration)

            @serial = []

            @instance = @wrapper.zemu_init
            @wrapper.zemu_power_on(@instance)
            @wrapper.zemu_reset(@instance)

            @state = RunState::UNDEFINED

            @breakpoints = {}
        end

        # Returns the clock speed of this instance in Hz.
        def clock_speed
            return @clock
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

        # Write a string to the serial line of the emulated CPU.
        #
        # @param string The string to be sent.
        #
        # Sends each character in the string to the receive buffer of the
        # emulated machine.
        def serial_puts(string)
            string.each_char do |c|
                @wrapper.zemu_io_serial_master_puts(c.ord)
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

            actual_count = @wrapper.zemu_io_serial_buffer_size()

            if count.nil? || actual_count < count
                count = actual_count
            end

            count.to_i.times do
                return_string += @wrapper.zemu_io_serial_master_gets().chr
            end

            return return_string
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

            configuration.io.each do |device|
                device.functions.each do |f|
                    wrapper.attach_function(f["name"], f["args"], f["return"])
                end
            end

            return wrapper
        end

        private :make_wrapper
    end
end
