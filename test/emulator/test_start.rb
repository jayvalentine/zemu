require 'minitest/autorun'
require 'zemu'

class StartTest < Minitest::Test
    BIN = File.join(__dir__, "..", "..", "bin")

    def test_start
        conf = Zemu::Config.new do
            name "zemu"

            output_directory BIN

            add_memory (Zemu::Config::ROM.new do
                name "rom"
                address 0x0000
                size 0x1000

                # 0x76 is the opcode for the HALT instruction.
                contents [0x76]
            end)
        end

        instance = Zemu.start(conf)

        # Run until halt
        instance.continue

        assert instance.halted?

        # Quit
        instance.quit
    end
end
