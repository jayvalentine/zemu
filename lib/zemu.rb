require 'erb'

require_relative 'zemu/config'
require_relative 'zemu/instance'

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

    # Build and start an emulator according to the given configuration.
    #
    # @param [Zemu::Config] configuration The configuration for which an emulator will be generated.
    def Zemu::start(configuration)
        build(configuration)

        return Instance.new(configuration)
    end

    # Builds a library according to the given configuration.
    #
    # @param [Zemu::Config] configuration The configuration for which an emulator will be generated.
    #
    # @returns true if the build is a success, false (build failed) or nil (compiler not found) otherwise.
    def Zemu::build(configuration)
        # Create the output directory unless it already exists.
        unless Dir.exist? configuration.output_directory
            Dir.mkdir configuration.output_directory
        end
        
        # Generate the autogenerated source files.
        generate(configuration)

        output = File.join(configuration.output_directory, "#{configuration.name}.so")

        autogen = File.join(configuration.output_directory, "autogen_#{configuration.name}")

        compiler = configuration.compiler

        inputs = [
            "main.c",                       # main library functionality
            "debug.c",                      # debug functionality
            "interrupt.c",                  # interrupt functionality
            "external/z80/sources/Z80.c"    # z80 core library
        ]

        inputs_str = inputs.map { |i| File.join(SRC, i) }.join(" ")

        inputs_str += " " + File.join(autogen, "memory.c") + " " + File.join(autogen, "io.c")

        defines = {
            "CPU_Z80_STATIC" => 1,
            "CPU_Z80_USE_LOCAL_HEADER" => 1
        }

        defines_str = defines.map { |d, v| "-D#{d}=#{v}" }.join(" ")

        includes = [
            "external/Z/API",
            "external/z80/API",
            "external/z80/API/emulation/CPU",
            "."
        ]

        includes_str = includes.map { |i| "-I#{File.join(SRC, i)}" }.join(" ")

        includes_str += " -I" + autogen

        command = "#{compiler} -Werror -Wno-unknown-warning-option -fPIC -shared -Wl,-undefined -Wl,dynamic_lookup #{includes_str} #{defines_str} -o #{output} #{inputs_str}"
        
        # Run the compiler and generate a library.
        return system(command)
    end

    # Generates the prerequisite source and header files for a given configuration.
    #
    # @param [Zemu::Config] configuration The configuration for which an emulator will be generated.
    def Zemu::generate(configuration)
        generate_memory(configuration)
        generate_io(configuration)
    end

    # Generates the memory.c and memory.h files for a given configuration.
    def Zemu::generate_memory(configuration)
        header_template = ERB.new File.read(File.join(SRC, "memory.h.erb"))
        source_template = ERB.new File.read(File.join(SRC, "memory.c.erb"))

        autogen = File.join(configuration.output_directory, "autogen_#{configuration.name}")

        unless Dir.exist? autogen
            Dir.mkdir autogen
        end

        File.write(File.join(autogen, "memory.h"),
                   header_template.result(configuration.get_binding))

        File.write(File.join(autogen, "memory.c"),
                   source_template.result(configuration.get_binding))
    end

    # Generates the io.c and io.h files for a given configuration.
    def Zemu::generate_io(configuration)
        header_template = ERB.new File.read(File.join(SRC, "io.h.erb"))
        source_template = ERB.new File.read(File.join(SRC, "io.c.erb"))

        autogen = File.join(configuration.output_directory, "autogen_#{configuration.name}")

        unless Dir.exist? autogen
            Dir.mkdir autogen
        end

        File.write(File.join(autogen, "io.h"),
                   header_template.result(configuration.get_binding))

        File.write(File.join(autogen, "io.c"),
                   source_template.result(configuration.get_binding))
    end
end