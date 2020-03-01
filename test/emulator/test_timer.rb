require 'minitest/autorun'
require 'zemu'

class TimerTest < Minitest::Test
    BIN = File.join(__dir__, "..", "..", "bin")

    def teardown
        @instance.quit unless @instance.nil?
    end

    def test_interrupt
        conf = Zemu::Config.new do
            name "zemu_interrupt"

            output_directory BIN

            add_memory (Zemu::Config::ROM.new do
                name "rom"
                address 0x0000
                size 0x1000

                contents from_binary(File.join(__dir__, "test_interrupt.bin"))
            end)

            add_io (Zemu::Config::Timer.new do
                name "timer_nmi"
                count_port 0x00
                control_port 0x01
            end)
        end

        @instance = Zemu.start(conf)

        # Set a breakpoint on the ISR.
        @instance.break 0x66, :program

        # Run until break.
        @instance.continue

        # We'd expect to be in the ISR.
        assert @instance.break?, "Expected to hit breakpoint."
        assert_equal 0x66, @instance.registers["PC"], "Expected to hit breakpoint in ISR."

        # Run until break.
        @instance.continue

        # We'd expect to be in the ISR.
        assert @instance.break?, "Expected to hit breakpoint."
        assert_equal 0x66, @instance.registers["PC"], "Expected to hit breakpoint in ISR."

        # Assert the contents of B.
        # We'd expect the loop to have executed more than once.
        assert (@instance.registers["B"] > 1), "Expected loop counter to have incremented more than once."
    end
end
