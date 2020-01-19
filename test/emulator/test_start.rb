require 'minitest/autorun'
require 'zemu'

class StartTest < Minitest::Test
    BIN = File.join(__dir__, "..", "..", "bin")

    def teardown
        @instance.quit unless @instance.nil?
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

        @instance = Zemu.start(conf)

        # Set breakpoint on address of third NOP.
        @instance.break 0x0002, :program

        # Run until break
        @instance.continue

        # Assert that we've hit the breakpoint.
        assert @instance.break?
        assert_equal 0x0002, @instance.registers["PC"]

        # Run until halt
        @instance.continue

        # Assert that we've halted.
        assert @instance.halted?
    end

    def test_memory_write
        conf = Zemu::Config.new do
            name "zemu_memory_write"

            output_directory BIN

            add_memory (Zemu::Config::ROM.new do
                name "rom"
                address 0x0000
                size 0x1000
                
                # Write a value to RAM, read it, and then halt.
                contents [
                    0x21, 0x04, 0x20,   # 0x0000: LD HL, #0x2004
                    0x3e, 0xa5,         # 0x0003: LD A, #0xa5
                    0x77,               # 0x0005: LD (HL), A
                    0x46,               # 0x0006: LD B, (HL)
                    0x76,               # 0x0007: HALT
                ]
            end)

            add_memory (Zemu::Config::RAM.new do
                name "ram"
                address 0x2000
                size 0x100
            end)
        end

        @instance = Zemu.start(conf)

        # Set a breakpoint on the LD (HL), A
        @instance.break 0x0005, :program
        
        # Set a breakpoint on the LD B, (HL)
        @instance.break 0x0006, :program

        @instance.continue

        # At this point we expect the value in memory to be 0.
        assert_equal @instance.memory(0x2004), 0x00

        @instance.continue

        # At this point we expect to have written to memory.
        assert_equal @instance.memory(0x2004), 0xa5

        @instance.continue

        # At this point we expect to have loaded the value from memory.
        assert_equal @instance.registers["B"], 0xa5
    end
end
