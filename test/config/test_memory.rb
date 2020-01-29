require 'minitest/autorun'
require 'zemu'

module Config
    # Tests memory configuration objects.
    class MemoryTest < Minitest::Test
        BIN = File.join(__dir__, "..", "..", "bin")

        # We should not be able to create an instance of the abstract memory class.
        def test_no_initialize_abstract
            e = assert_raises NotImplementedError do
                _ = Zemu::Config::Memory.new do
                    address 0x0000
                    size 0x1000
                end
            end

            assert_equal "Cannot construct an instance of the abstract class Zemu::Config::Memory.", e.message
        end

        # We should be able to create a ROM memory object with a valid size and address.
        def test_initialize_rom
            mem = Zemu::Config::ROM.new do
                name "my_rom"
                address 0x0000
                size 0x1000
            end

            assert_equal "my_rom", mem.name
            assert_equal 0x0000, mem.address
            assert_equal 0x1000, mem.size
        end

        # We have to set the address parameter of a ROM object.
        def test_must_set_address
            e = assert_raises Zemu::ConfigError do
                _ = Zemu::Config::ROM.new do
                    size 0x1000
                    name "my_rom"
                end
            end

            assert_equal "The address parameter of a Zemu::Config::ROM configuration object must be set.", e.message
        end

        # We have to set the size parameter of a ROM object.
        def test_must_set_size
            e = assert_raises Zemu::ConfigError do
                _ = Zemu::Config::ROM.new do
                    address 0x8000
                    name "my_rom"
                end
            end

            assert_equal "The size parameter of a Zemu::Config::ROM configuration object must be set.", e.message
        end

        # We have to set the name parameter of a ROM object.
        def test_must_set_name
            e = assert_raises Zemu::ConfigError do
                _ = Zemu::Config::ROM.new do
                    address 0x8000
                    size 0x1000
                end
            end

            assert_equal "The name parameter of a Zemu::Config::ROM configuration object must be set.", e.message
        end

        # A ROM object should by default be filled with 0x00 bytes.
        def test_initial_val_default
            mem = Zemu::Config::ROM.new do
                name "my_rom"
                address 0x8000
                size 0x1000
            end

            assert_equal 0x1000, mem.contents.size
            mem.contents.each do |b|
                assert_equal 0x00, b
            end
        end

        # A ROM object can be initialized with an array of numbers N where 0 <= N < 256.
        def test_initial_val_set_array
            mem = Zemu::Config::ROM.new do
                name "my_rom"
                address 0x8000
                size 0x1000

                contents [0, 255, 100, 20, 42, 1, 254]
            end

            assert_equal 0x1000, mem.contents.size
            assert_equal [0, 255, 100, 20, 42, 1, 254], mem.contents[0..6]
            mem.contents[7..-1].each do |b|
                assert_equal 0x00, b
            end
        end

        # A ROM object can be initialized from a binary file.
        def test_initial_val_from_bin
            # Create the binary file.
            File.open(File.join(BIN, "app.bin"), "wb") do |f|
                f.write "\x01"
                f.write "\xaa"
                f.write "\x12"
                f.write "\x42"
                f.write "\xde"
            end

            mem = Zemu::Config::ROM.new do
                name "my_rom"
                address 0x8000
                size 0x1000

                contents from_binary(File.join(BIN, "app.bin"))
            end

            assert_equal 0x1000, mem.contents.size
            assert_equal [0x01, 0xaa, 0x12, 0x42, 0xde], mem.contents[0..4]
            mem.contents[5..-1].each do |b|
                assert_equal 0x00, b
            end
        end
    end
end