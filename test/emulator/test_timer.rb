require 'minitest/autorun'
require 'zemu'

class TimerTest < Minitest::Test
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

    def test_interrupt
        # Assemble the test program.
        asm <<-eos
        org     $0000
    start:
        jp      main
    
        org     $0066
    nmi:
        reti
    
        org     $0100
    main:
        ld      B, $0
    main_loop:
        inc     B
        jp      main_loop
    
eos

        conf = Zemu::Config.new do
            name "zemu_interrupt"

            output_directory BIN

            add_memory (Zemu::Config::ROM.new do
                name "rom"
                address 0x0000
                size 0x1000

                contents from_binary(File.join(BIN, "temp.bin"))
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

        # Run for 1000 cycles. We'd expect to hit the ISR before then.
        @instance.continue(1000)

        # We'd expect to be in the ISR.
        assert @instance.break?, "Expected to hit breakpoint."
        assert_equal 0x66, @instance.registers["PC"], "Expected to hit breakpoint in ISR."

        # Assert the contents of B.
        # We'd expect the loop to have executed more than once.
        assert (@instance.registers["B"] > 1), "Expected loop counter to have incremented more than once."
    end
end
