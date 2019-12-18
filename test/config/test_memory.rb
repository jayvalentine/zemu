require 'minitest/autorun'
require 'zemu'

module Config
    # Tests memory configuration objects.
    class MemoryTest < Minitest::Test
        # We should not be able to create an instance of the abstract memory class.
        def test_no_initialize_abstract
            e = assert_raises NotImplementedError do
                _ = Zemu::Config::Memory.new do |m|
                    m.address = 0x0000
                    m.size = 0x1000
                end
            end

            assert_equal "Cannot construct an instance of the abstract class Zemu::Config::Memory.", e.message
        end

        # We should be able to create a ROM memory object with a valid size and address.
        def test_initialize_rom
            mem = Zemu::Config::ROM.new do |m|
                m.name = "my_rom"
                m.address = 0x0000
                m.size = 0x1000
            end

            assert_equal "my_rom", mem.name
            assert_equal 0x0000, mem.address
            assert_equal 0x1000, mem.size
        end

        # We have to set the address parameter of a ROM object.
        def test_must_set_address
            e = assert_raises Zemu::ConfigError do
                _ = Zemu::Config::ROM.new do |m|
                    m.size = 0x1000
                    m.name = "my_rom"
                end
            end

            assert_equal "The address parameter of a Memory configuration object must be set.", e.message
        end

        # We have to set the size parameter of a ROM object.
        def test_must_set_size
            e = assert_raises Zemu::ConfigError do
                _ = Zemu::Config::ROM.new do |m|
                    m.address = 0x8000
                    m.name = "my_rom"
                end
            end

            assert_equal "The size parameter of a Memory configuration object must be set.", e.message
        end
    end
end