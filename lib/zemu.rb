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
end