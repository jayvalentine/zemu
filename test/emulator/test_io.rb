require 'minitest/autorun'
require 'zemu'

class WriteOnlyPort < Zemu::Config::BusDevice
    def initialize
        super

        @reg_value = 0
    end

    def io_read(port)
        nil
    end
        
    def io_write(port, value)
        if port == wport
            @reg_value = value
        end
    end

    def register_value
        @reg_value
    end

    def functions
        [
        ]
    end

    def params
        super + %w(wport)
    end
end

class IOTest < Minitest::Test
    BIN = File.join(__dir__, "..", "..", "bin")

    def teardown
        @instance.quit unless @instance.nil?
    end

    def asm(string)
        # Write the string to a temporary asm file.
        File.open(File.join(BIN, "temp.asm"), "w+") { |f| f.puts string }

        # Assemble.
        `vasmz80_oldstyle -Fbin -o #{File.join(BIN, "temp.bin")} #{File.join(BIN, "temp.asm")}`
    end

    # Tests that a device with an attached function
    # results in a function of the same name defined
    # on the instance.
    def test_attached_function
        asm <<-EOF
    ld      B, $05
    ld      HL, _data
_loop5:                 ; Addr 0x0005
    ld      A, (HL)
    inc     HL
    out     ($80), A
    djnz    _loop5

    halt

_data:
    defb    $11, $22, $33, $44, $55
EOF

        conf = Zemu::Config.new do
            name "zemu_attached_function"

            output_directory BIN

            add_memory (Zemu::Config::ROM.new do
                name "rom"
                address 0x0000
                size 0x1000

                contents from_binary(File.join(BIN, "temp.bin"))
            end)

            add_io (WriteOnlyPort.new do
                name "wport"
                wport 0x80
            end)
        end

        @instance = Zemu.start(conf)
        
        @instance.break 0x0005, :program

        port_values = [0x00, 0x11, 0x22, 0x33, 0x44, 0x55]

        # Should hit the breakpoint 5 times.
        5.times do |i|
            @instance.continue
            assert @instance.break?, "Did not hit breakpoint on iteration #{i}!"

            # Check value of the port.
            actual_value = @instance.device('wport').register_value
            assert_equal port_values[i], actual_value, "Wrong value on iteration #{i}!"
        end

        # Run until halt
        @instance.continue
        assert @instance.halted?, "Instance did not halt!"

        # Check final value of port.
        actual_value = @instance.device('wport').register_value
        assert_equal port_values[5], actual_value, "Wrong final port value!"
    end
end
