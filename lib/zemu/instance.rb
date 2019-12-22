require 'ffi'

module Zemu
    class Instance
        def initialize(configuration)
            @wrapper = make_wrapper(configuration)
        end

        def make_wrapper(configuration)
            wrapper = Module.new

            wrapper.extend FFI::Library

            wrapper.ffi_lib ["#{configuration.name}.so"]

            wrapper.attach_function :zemu_init, [], :pointer

            return wrapper
        end
    end
end
