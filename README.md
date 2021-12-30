# zemu

## Introduction

Zemu is a configurable Z80 emulator, mainly intended for integration into build and test suites.
However, it can also be used as an interactive emulator from the command-line.

## License

The Z and Z80 libraries (src/external/Z, src/external/z80) are copyright (c) Manuel Sainz de Baranda y Goñi.

All Zemu Ruby and C source code (except where listed above) is copyright (c) Jay Valentine.

Released under the terms of the GNU General Public License v3.

## Installation

Zemu can be installed from RubyGems.org:

```
gem install zemu
```

In addition to the gem, a compatible compiler must be installed.
Currently, the only supported compiler is clang. If this is not already
installed on your system, you must follow system-appropriate installation instructions
to install it before you can use Zemu.

## New in v1.0.0

### Implementing device logic in Ruby

Device logic is now implemented in Ruby, rather than C.
The Ruby implementations are called via FFI callbacks at runtime.

This allows the definition of a system configuration, including
new devices, without having to write any C.

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

    add_device Zemu::Config::ROM.new do
        name "rom"
        address 0x0000
        size 0x4000

        contents from_binary("app.bin")
    end

    add_device Zemu::Config::RAM.new do
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

### Defining new devices

New devices can be defined by inheriting from the `Zemu::Config::BusDevice` class.
The device can redefine the `mem_read`, `mem_write`, `io_read`, `io_write`, and `clock` functions
as appropriate to define the run-time behaviour.

Additionally, methods on the device can provide access to its internal state.

```ruby
require 'zemu'

# Register mapped to an IO port.
class Register < Zemu::Config::BusDevice
    def initialize
        super

        @reg_state = 0
    end

    def params
        super + %w(io_port)

    def io_write(port, value)
        # Port decode logic is local to each
        # device. This allows multiple
        # devices to listen on the same port.
        if port == io_port
            @reg_state = value
        end
    end

    def io_read(port)
        if port == io_port
            return @reg_state
        end

        # Read operations return nil
        # if the port is not applicable
        # - e.g. does not correspond to
        # this device.
        nil
    end

    def get_reg_state
        @reg_state
    end
end
```

The new device can be initialized as part of a configuration.
Methods of the device can be used at run-time via the `Zemu::Instance#device` method.

```ruby
conf = Zemu::Config.new do
    name "zemu_emulator"

    add_device Zemu::Config::ROM.new do
        name "rom"
        address 0x0000
        size 0x4000

        contents from_binary("app.bin")
    end

    add_device Zemu::Config::RAM.new do
        name "ram"
        address 0x8000
        size 0x1000
    end

    add_device Register.new do
        name "reg"
        io_port 0x12
    end
end

# Start a new instance with this configuration.
instance = Zemu.start(conf)

# Continue for 100 cycles.
instance.continue(100)

# Get value of register.
reg_value = instance.device('reg').get_reg_state

# Close the instance.
instance.quit
```

## Documentation

Where possible, code examples have been given to show how the various configuration options can be used.
In addition, API documentation should be complete enough to indicate how to construct a configuration.

If this is not the case, please let me know!

Documentation for the gem can be found [here](https://www.rubydoc.info/gems/zemu).

## Compatibility

Zemu has currently only been tested with one OS (Linux) and one compiler (clang), so compatibility with
other environments is not guaranteed. Please raise an issue if you encounter an issue, giving the details
of your environment, so that it can be resolved!
