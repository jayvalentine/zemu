require 'minitest/autorun'
require 'zemu'

module Config
    # Tests memory configuration objects.
    class IOTest < Minitest::Test
        # We should not be able to create an instance of the abstract IOPort class.
        def test_no_initialize_abstract
            e = assert_raises NotImplementedError do
                _ = Zemu::Config::IOPort.new do
                    name "io"
                end
            end

            assert_equal "Cannot construct an instance of the abstract class Zemu::Config::IOPort.", e.message
        end

        # We should be able to initialize an instance of the serial class.
        def test_serial
            serial = Zemu::Config::SerialPort.new do
                name "serial"
                in_port 0x00
                out_port 0x01
                ready_port 0x02
            end

            assert_equal "serial", serial.name
            assert_equal 0x00, serial.in_port
            assert_equal 0x01, serial.out_port
            assert_equal 0x02, serial.ready_port
        end

        # We should be able to initialize an instance of the timer class.
        def test_timer
            timer = Zemu::Config::Timer.new do
                name "timer"
                count_port 0x00
                control_port 0x01
            end

            assert_equal "timer", timer.name
            assert_equal 0x00, timer.count_port
            assert_equal 0x01, timer.control_port
        end
    end
end
