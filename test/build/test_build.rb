require 'minitest/autorun'
require 'zemu'

module Build
    class BuildTest < Minitest::Test
        # We should be able to build a simple test case with just a ROM section,
        # with the default compiler settings.
        def test_simple_default
            conf = Zemu::Config.new do
                name "zemu"
                
                add_memory (Zemu::Config::ROM.new do
                    name "rom"
                    address 0x0000
                    size 0x1000
                end)

                result = Zemu.build(conf)

                assert_true result

                assert_true File.exist?("zemu.so")
            end
        end
    end
end
