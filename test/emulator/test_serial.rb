require 'minitest/autorun'
require 'zemu'

class SerialTest < Minitest::Test
    BIN = File.join(__dir__, "..", "..", "bin")

    def teardown
        @instance.quit unless @instance.nil?
    end

    def test_read
        conf = Zemu::Config.new do
            name "zemu_read"

            output_directory BIN

            add_memory (Zemu::Config::ROM.new do
                name "rom"
                address 0x0000
                size 0x1000

                contents [
                    0x06, 0x05,         # 0x0000: LD B, #0x05
                    0x21, 0x00, 0x20,   # 0x0002: LD HL, #0x2000
                    0xdb, 0x00,         # 0x0005: IN A, #0x00
                    0x77,               # 0x0007: LD (HL), A
                    0x23,               # 0x0008: INC HL
                    0x10, 0xfa,         # 0x0009: DJNZ #0x0005 (-6)
                    0x76                # 0x0011: HALT
                ]
            end)

            add_memory (Zemu::Config::RAM.new do
                name "ram"
                address 0x2000
                size 0x100
            end)

            add_io (Zemu::Config::SerialPort.new do
                name "serial"
                in_port 0x00
                out_port 0x01
                ready_port 0x02
            end)
        end

        @instance = Zemu.start(conf)

        @instance.serial_puts "Hello"

        # Run until halt
        @instance.continue

        assert @instance.halted?

        # Assert the contents of memory.
        assert_equal 0x48, @instance.memory(0x2000)
        assert_equal 0x65, @instance.memory(0x2001)
        assert_equal 0x6c, @instance.memory(0x2002)
        assert_equal 0x6c, @instance.memory(0x2003)
        assert_equal 0x6f, @instance.memory(0x2004)
    end

    def test_write
        conf = Zemu::Config.new do
            name "zemu_write"

            output_directory BIN

            add_memory (Zemu::Config::ROM.new do
                name "rom"
                address 0x0000
                size 0x1000

                contents [
                    0x3e, 0x48,         # 0x0000: LD A, #'H'
                    0xd3, 0x01,         # 0x0002: OUT #0x01, A
                    0x3e, 0x65,         # 0x0004: LD A, #'e'
                    0xd3, 0x01,         # 0x0006: OUT #0x01, A
                    0x3e, 0x6c,         # 0x0008: LD A, #'l'
                    0xd3, 0x01,         # 0x000a: OUT #0x01, A
                    0x3e, 0x6c,         # 0x000c: LD A, #'l'
                    0xd3, 0x01,         # 0x000e: OUT #0x01, A
                    0x3e, 0x6f,         # 0x0010: LD A, #'o'
                    0xd3, 0x01,         # 0x0012: OUT #0x01, A
                    0x76                # 0x0014: HALT
                ]
            end)

            add_memory (Zemu::Config::RAM.new do
                name "ram"
                address 0x2000
                size 0x100
            end)

            add_io (Zemu::Config::SerialPort.new do
                name "serial"
                in_port 0x00
                out_port 0x01
                ready_port 0x02
            end)
        end

        @instance = Zemu.start(conf)

        # Run until halt
        @instance.continue

        assert @instance.halted?

        assert_equal "Hello", @instance.serial_gets(5)
    end

    def test_write_get_all
        conf = Zemu::Config.new do
            name "zemu_write_get_all"

            output_directory BIN

            add_memory (Zemu::Config::ROM.new do
                name "rom"
                address 0x0000
                size 0x1000

                contents [
                    0x3e, 0x48,         # 0x0000: LD A, #'H'
                    0xd3, 0x01,         # 0x0002: OUT #0x01, A
                    0x3e, 0x65,         # 0x0004: LD A, #'e'
                    0xd3, 0x01,         # 0x0006: OUT #0x01, A
                    0x3e, 0x6c,         # 0x0008: LD A, #'l'
                    0xd3, 0x01,         # 0x000a: OUT #0x01, A
                    0x3e, 0x6c,         # 0x000c: LD A, #'l'
                    0xd3, 0x01,         # 0x000e: OUT #0x01, A
                    0x3e, 0x6f,         # 0x0010: LD A, #'o'
                    0xd3, 0x01,         # 0x0012: OUT #0x01, A
                    0x76                # 0x0014: HALT
                ]
            end)

            add_memory (Zemu::Config::RAM.new do
                name "ram"
                address 0x2000
                size 0x100
            end)

            add_io (Zemu::Config::SerialPort.new do
                name "serial"
                in_port 0x00
                out_port 0x01
                ready_port 0x02
            end)
        end

        @instance = Zemu.start(conf)

        # Run until halt
        @instance.continue

        assert @instance.halted?

        assert_equal "H", @instance.serial_gets(1)
        assert_equal "ello", @instance.serial_gets()
    end
end
