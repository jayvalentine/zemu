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

        # We should be able to initialize an instance of the block drive class.
        # With no input file the contents will be empty.
        def test_block_drive
            drive = Zemu::Config::BlockDrive.new do
                name "drive"
                base_port 0x00
                sector_size 512
                num_sectors 64
            end

            assert_equal "drive", drive.name
            assert_equal 0x00, drive.base_port
            assert_equal 512, drive.sector_size
            assert_equal 64, drive.num_sectors

            assert_equal 64, drive.blocks.size
            drive.blocks.each do |block|
                assert_equal 512, block.size
                block.each do |b|
                    assert_equal 0, b
                end
            end
        end

        # We should be able to initialize an instance of the block drive class.
        # With an input file the block data will reflect the file.
        def test_block_drive_from_file
            # Write a binary file.
            File.open("file.bin", "wb+") do |f|
                8.times do |i|
                    16.times do |j|
                        f.write [i+j].pack("C")
                    end
                end
            end

            drive = Zemu::Config::BlockDrive.new do
                name "drive"
                base_port 0x00
                sector_size 16
                num_sectors 8

                initialize_from "file.bin"
            end

            assert_equal "drive", drive.name
            assert_equal 0x00, drive.base_port
            assert_equal 16, drive.sector_size
            assert_equal 8, drive.num_sectors

            8.times do |i|
                16.times do |j|
                    assert_equal i+j, drive.blocks[i][j]
                end
            end
        end

        # Attempting to initialize a block drive from a file
        # of wrong length should fail.
        def test_block_drive_wrong_file_size
            # Write a binary file.
            File.open("file.bin", "wb+") do |f|
                8.times do |i|
                    15.times do |j|
                        f.write [i+j].pack("C")
                    end
                end
            end

            e = assert_raises RangeError do
                drive = Zemu::Config::BlockDrive.new do
                    name "drive"
                    base_port 0x00
                    sector_size 16
                    num_sectors 8

                    initialize_from "file.bin"
                end
            end

            assert_equal "Initialization file for Zemu::Config::BlockDrive 'drive' is of wrong size.", e.message
        end
    end
end
