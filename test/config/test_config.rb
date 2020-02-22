require 'minitest/autorun'
require 'zemu'

module Config
    # Tests the overall behaviour of the config object.
    class ConfigTest < Minitest::Test
        # We should not be able to construct a ConfigObject directly.
        def test_no_construct_abstract
            e = assert_raises NotImplementedError do
                _ = Zemu::ConfigObject.new do
                    some_param "blah"
                end
            end

            assert_equal "Cannot construct an instance of the abstract class Zemu::ConfigObject.", e.message
        end

        # We should be able to add a memory section to a config object.
        def test_add_memory
            conf = Zemu::Config.new do
                name "my_config"

                add_memory (Zemu::Config::ROM.new do
                    name "my_rom"
                    address 0x8000
                    size 0x1000
                end)
            end

            assert_equal "my_rom", conf.memory[0].name
            assert_equal 0x8000, conf.memory[0].address
            assert_equal 0x1000, conf.memory[0].size
        end

        # A configuration can be given a clock speed in Hz.
        def test_clock_speed
            conf = Zemu::Config.new do
                name "my_config"
                clock_speed 1_000_000 # 1 MHz.
            end

            assert_equal 1_000_000, conf.clock_speed
        end
    end
end