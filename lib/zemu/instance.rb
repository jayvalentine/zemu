require 'ffi'
require 'ostruct'

module Zemu
    # Represents an instance of a Zemu emulator.
    #
    # Provides methods by which the state of the emulator can be observed
    # and the execution of the program controlled.
    class Instance
        def initialize(configuration)
            @wrapper = make_wrapper(configuration)

            @instance = @wrapper.zemu_init
            @wrapper.zemu_power_on(@instance)
            @wrapper.zemu_reset(@instance)
        end

        # Returns an [OpenStruct] with the following attributes:
        # * pc => current program counter value
        def registers
            r = OpenStruct.new
            r.pc = @wrapper.zemu_debug_register(@instance, 0)
            
            return r
        end

        # Continue running this instance until either:
        # * A HALT instruction is executed
        # * A breakpoint is hit
        def continue
            @wrapper.zemu_debug_continue(@instance)
        end

        # Set a breakpoint of the given type at the given address.
        #
        # @param address The address of the breakpoint
        # @param type The type of breakpoint:
        #   * :program => Break when the program counter hits the address given. 
        def break(address, type)
            @wrapper.zemu_debug_set_breakpoint(address)
        end

        # Returns true if the CPU has halted, false otherwise.
        def halted?
            return @wrapper.zemu_debug_halted
        end

        # Returns true if a breakpoint has been hit, false otherwise.
        def break?
            return @wrapper.zemu_debug_break
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

            wrapper.attach_function :zemu_debug_continue, [:pointer], :void

            wrapper.attach_function :zemu_debug_halted, [], :bool
            wrapper.attach_function :zemu_debug_break, [], :bool

            wrapper.attach_function :zemu_debug_set_breakpoint, [:uint16], :void

            wrapper.attach_function :zemu_debug_register, [:pointer, :uint16], :uint16

            return wrapper
        end

        private :make_wrapper
    end
end
