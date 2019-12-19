require_relative 'zemu/config'

# Zemu
#
# Zemu is a module providing an interface to build and interact with
# configurable Z80 emulators.
#
# Configurations can be defined in a declarative syntax, from which
# an emulator executable can be compiled. This executable can then be run
# from within Zemu and controlled programmatically.
#
# Please note: The example below does not currently work, as not all features
# have been implemented.
#
# @example
#
#   require 'zemu'
#
#   # A simple configuration with a ROM block
#   # and a RAM block.
#   conf = Zemu::Config.new do
#       name "zemu_emulator"
#
#       add_memory Zemu::Config::ROM.new do
#           name "rom"
#           address 0x0000
#           size 0x4000
#
#           contents from_binary("app.bin")
#       end
#
#       add_memory Zemu::Config::RAM.new do
#           name "ram"
#           address 0x8000
#           size 0x1000
#       end
#   end
#
#   # Start a new instance with this configuration.
#   instance = Zemu.start(conf)
#
#   # Program breakpoint.
#   # Will trigger if the emulator is about to execute an
#   # instruction at 0x102.
#   instance.break 0x102, :program
#
#   # Continue. Emulator will run until HALT or until
#   # the breakpoint (set above) is hit.
#   instance.continue
#
#   # Display the value of the A register (accumulator)
#   # at the breakpoint.
#   puts instance.register["A"]
#
#   # Close the instance.
#   instance.quit
#
module Zemu
    # Location of C source for the emulator.
    SRC = File.join(__dir__, "..", "src")

    # Location for build libraries.
    BIN = File.join(__dir__, "..", "bin")

    # Builds a library according to the given configuration.
    #
    # @param [Zemu::Config] configuration The configuration for which an emulator will be generated.
    #
    # @returns true if the build is a success, false (build failed) or nil (compiler not found) otherwise.
    def Zemu::build(configuration)
        output = File.join(BIN, "#{configuration.name}.so")

        compiler = configuration.compiler

        inputs = [
            "main.c",                       # main library functionality
            "debug.c",                      # debug functionality
            "memory.c",                     # memory modules defined in config
            "external/z80/sources/Z80.c"    # z80 core library
        ]

        inputs_str = inputs.map { |i| File.join(SRC, i) }.join(" ")

        defines = {
            "CPU_Z80_STATIC" => 1,
            "CPU_Z80_USE_LOCAL_HEADER" => 1
        }

        defines_str = defines.map { |d, v| "-D#{d}=#{v}" }.join(" ")

        command = "#{compiler} -fPIC -shared -Wl,-undefined -Wl,dynamic_lookup #{defines_str} -o #{output} #{inputs_str}"

        # Run the compiler and generate a library.
        return system(command)
    end
end