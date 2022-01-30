require 'minitest/autorun'
require 'zemu'

# Tests for the functionality of Instance#trace,
# which allows for executing arbitrary procs on execution
# at a user-defined address.
class TraceTest < Minitest::Test
    BIN = File.join(__dir__, "..", "..", "bin")

    def asm(string)
        # Write the string to a temporary asm file.
        File.open(File.join(BIN, "temp.asm"), "w+") { |f| f.puts string }

        # Assemble.
        `vasmz80_oldstyle -Fbin -o #{File.join(BIN, "temp.bin")} #{File.join(BIN, "temp.asm")}`
    end

    def teardown
        @instance.quit unless @instance.nil?
    end

    # Tests that tracepoints can be set via Instance#trace,
    # and that they are executed at the appropriate time.
    def test_trace
        # Assemble the test program.
        asm <<-eos
    org     $0000
start:
    jp      label1
    
    org     $0100
label1:
    ld      HL, 1
    jp      label2

    org     $0123
label3:
    jp      label3

    org     $0250
label2:
    inc     HL
    jp      label3
eos

        conf = Zemu::Config.new do
            name "zemu_trace"

            output_directory BIN

            add_memory (Zemu::Config::ROM.new do
                name "rom"
                address 0x0000
                size 0x1000

                contents from_binary(File.join(BIN, "temp.bin"))
            end)
        end

        @instance = Zemu.start(conf)

        @traces = 0

        # Set two tracepoints.
        # Check the values at each point.
        @instance.trace(0x0123) do |i|
            assert_equal 1, @traces
            @traces += 1

            assert_equal 2, i.registers["HL"]
            assert_equal 0x0123, i.registers["PC"]
        end

        @instance.trace(0x0250) do |i|
            assert_equal 0, @traces
            @traces += 1

            assert_equal 1, i.registers["HL"]
            assert_equal 0x0250, i.registers["PC"]
        end

        assert_equal 0, @traces

        # Set a breakpoint and continue til we hit it.
        @instance.break 0x0123, :program
        @instance.continue(1000)

        # We'd expect to have hit the breakpoint.
        assert @instance.break?, "Expected to hit breakpoint."
        
        # Should have executed both traces once.
        assert_equal 2, @traces
    end

    # Tests that tracepoints with wrong arity will result in
    # an exception.
    def test_wrong_arity_0
        # Assemble the test program.
        asm <<-eos
    org     $0000
start:
    jp      start
eos

        conf = Zemu::Config.new do
            name "zemu_trace_wrong_arity_0"

            output_directory BIN

            add_memory (Zemu::Config::ROM.new do
                name "rom"
                address 0x0000
                size 0x1000

                contents from_binary(File.join(BIN, "temp.bin"))
            end)
        end

        @instance = Zemu.start(conf)

        @traces = 0

        # Set breakpoint using block with wrong arity.
        # Expect an exception.
        e = assert_raises Zemu::InstanceError do
            @instance.trace(0x0123) do
                puts "Wrong arity!"
                @traces = 42
            end
        end

        assert_equal "Wrong arity for tracepoint - expected 1, got 0", e.message
        assert_equal 0, @traces
    end

    # Tests that tracepoints with wrong arity will result in
    # an exception.
    def test_wrong_arity_2
        # Assemble the test program.
        asm <<-eos
    org     $0000
start:
    jp      start
eos

        conf = Zemu::Config.new do
            name "zemu_trace_wrong_arity_0"

            output_directory BIN

            add_memory (Zemu::Config::ROM.new do
                name "rom"
                address 0x0000
                size 0x1000

                contents from_binary(File.join(BIN, "temp.bin"))
            end)
        end

        @instance = Zemu.start(conf)

        @traces = 0

        # Set breakpoint using block with wrong arity.
        # Expect an exception.
        e = assert_raises Zemu::InstanceError do
            @instance.trace(0x0123) do |i, x|
                puts "Wrong arity!"
                @traces = 42
            end
        end

        assert_equal "Wrong arity for tracepoint - expected 1, got 2", e.message
        assert_equal 0, @traces
    end
end
