require 'minitest/autorun'
require 'zemu'

module Build
    class BuildTest < Minitest::Test
        BIN = File.join(__dir__, "..", "..", "bin")

        # We should be able to build a simple test case with just a ROM section,
        # with the default compiler settings.
        def test_simple_default
            conf = Zemu::Config.new do
                name "zemu"

                output_directory BIN
                
                add_memory (Zemu::Config::ROM.new do
                    name "rom"
                    address 0x0000
                    size 0x1000

                    contents [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF]
                end)
            end

            result = Zemu.build(conf)

            assert result

            assert File.exist?(File.join(BIN, "zemu.so"))
        end
    end
end
