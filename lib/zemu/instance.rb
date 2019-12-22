require 'ffi'

module Zemu
    class Instance
        def initialize(configuration)
            @wrapper = make_wrapper(configuration)

            @instance = @wrapper.zemu_init
            @wrapper.zemu_power_on(@instance)
            @wrapper.zemu_reset(@instance)
        end

        def continue
            @wrapper.zemu_debug_continue(@instance)
        end

        def make_wrapper(configuration)
            wrapper = Module.new

            wrapper.extend FFI::Library

            wrapper.ffi_lib [File.join(configuration.output_directory, "#{configuration.name}.so")]

            wrapper.attach_function :zemu_init, [], :pointer
            wrapper.attach_function :zemu_power_on, [:pointer], :void
            wrapper.attach_function :zemu_reset, [:pointer], :void

            wrapper.attach_function :zemu_debug_continue, [:pointer], :void

            return wrapper
        end
    end
end
