# zemu

## Introduction

Zemu is a configurable Z80 emulator, mainly intended for integration into build and test suites.
However, it can also be used as an interactive emulator from the command-line.

## License

The Z and Z80 libraries (src/external/Z, src/external/z80) are copyright (c) Manuel Sainz de Baranda y Goñi.

All Zemu Ruby and C source code (except where listed above) is copyright (c) Jay Valentine.

Released under the terms of the GNU General Public License v3.

## New in v0.3.0

### Improvement to Instance#continue

The Instance#continue method is now implemented directly in Ruby, rather than simply being
a wrapper around a C implementation. This will make it easier to extend debugging functionality
in the future.
### Non-Maskable Interrupt Timer

The Timer IO device has been added. This device provides an 8-bit register to which the emulated
machine can write a count. The count decreases by 1 for every cycle executed, and generates an NMI
once expired.
### Added Instance#remove_break method

Added the #remove_break method to the Instance class, which allows the removal
of a previously-set breakpoint.

## Usage

Configurations can be defined in a declarative syntax, from which
an emulator executable can be compiled. This executable can then be run
from within Zemu and controlled programmatically.

```ruby
require 'zemu'

# A simple configuration with a ROM block
# and a RAM block.
conf = Zemu::Config.new do
    name "zemu_emulator"

    add_memory Zemu::Config::ROM.new do
        name "rom"
        address 0x0000
        size 0x4000

        contents from_binary("app.bin")
    end

    add_memory Zemu::Config::RAM.new do
        name "ram"
        address 0x8000
        size 0x1000
    end
end

# Start a new instance with this configuration.
instance = Zemu.start(conf)

# Program breakpoint.
# Will trigger if the emulator is about to execute an
# instruction at 0x102.
instance.break 0x102, :program

# Continue. Emulator will run until HALT or until
# the breakpoint (set above) is hit.
instance.continue

# Display the value of the A register (accumulator)
# at the breakpoint.
puts instance.register["A"]

# Close the instance.
instance.quit
```

An interactive mode is also provided, which gives a command-line interface to the emulated
machine.

## Documentation

Where possible, code examples have been given to show how the various configuration options can be used.
In addition, API documentation should be complete enough to indicate how to construct a configuration.

If this is not the case, please let me know!

Documentation for the gem can be found [here](https://www.rubydoc.info/gems/zemu).

## Compatibility

Zemu has currently only been tested with one OS (Linux) and one compiler (clang), so compatibility with
other environments is not guaranteed. Please raise an issue if you encounter an issue, giving the details
of your environment, so that it can be resolved!
