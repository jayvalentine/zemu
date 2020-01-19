require 'minitest/autorun'
require 'zemu'

class StartTest < Minitest::Test
    BIN = File.join(__dir__, "..", "..", "bin")

    def teardown
        @instance.quit
    end

    def test_start
        conf = Zemu::Config.new do
            name "zemu_start"

            output_directory BIN

            add_memory (Zemu::Config::ROM.new do
                name "rom"
                address 0x0000
                size 0x1000

                # 0x76 is the opcode for the HALT instruction.
                contents [0x76]
            end)
        end

        @instance = Zemu.start(conf)

        # Run until halt
        @instance.continue

        assert @instance.halted?
    end

    def test_program_break
        conf = Zemu::Config.new do
            name "zemu_program_break"

            output_directory BIN

            add_memory (Zemu::Config::ROM.new do
                name "rom"
                address 0x0000
                size 0x1000
                
                # 3 NOPs and then a HALT
                [0x00, 0x00, 0x00, 0x76]
            end)
        end

        @instance = Zemu.start(conf)

        # Set breakpoint on address of third NOP.
        @instance.break 0x0002, :program

        # Run until break
        @instance.continue

        assert_equal 0x0002, @instance.registers["PC"]

        # Run until halt
        @instance.continue

        assert @instance.halted?

        # Quit
        @instance.quit
    end
end
