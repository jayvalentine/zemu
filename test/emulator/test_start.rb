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
                contents [0x00, 0x00, 0x00, 0x76]
            end)
        end

        puts "Before start"

        @instance = Zemu.start(conf)

        puts "Started"

        # Set breakpoint on address of third NOP.
        @instance.break 0x0002, :program

        puts "Set breakpoint"

        # Run until break
        @instance.continue

        puts "First Continue"

        assert_equal 0x0002, @instance.registers["PC"]

        puts "Assert hit breakpoint"

        # Run until halt
        @instance.continue

        puts "Second continue"

        assert @instance.halted?

        puts "Assert halted"
    end
end
