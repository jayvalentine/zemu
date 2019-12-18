require 'minitest/autorun'
require 'zemu'

module Config
    # Tests the overall behaviour of the config object.
    class ConfigTest < Minitest::Test
        # We should not be able to construct a ConfigObject directly.
        def test_no_construct_abstract
            e = assert_raises NotImplementedError do
                _ = Zemu::ConfigObject.new do |c|
                    c.some_param = "blah"
                end
            end

            assert_equal "Cannot construct an instance of the abstract class Zemu::Config::ConfigObject.", e.message
        end

        # We should be able to add a memory section to a config object.
        def test_add_memory
            conf = Zemu::Config.new do |c|
                c.name = "my_config"

                mem = Zemu::Config::ROM.new do |m|
                    m.name = "my_rom"
                    m.address = 0x8000
                    m.size = 0x1000
                end

                c.add_memory mem
            end

            assert_equal "my_rom", conf.memory[0].name
            assert_equal 0x8000, conf.memory[0].address
            assert_equal 0x1000, conf.memory[0].size
        end
    end
end