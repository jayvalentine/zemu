require 'minitest/autorun'
require 'zemu'

module Config
    # Tests memory configuration objects.
    class MemoryTest < Minitest::Test
        # We should not be able to create an instance of the abstract memory class.
        def test_no_initialize_abstract
            e = assert_raises NotImplementedError do
                mem = Zemu::Config::Memory.new do |m|
                    m.address = 0x0000
                    m.size = 0x1000
                end
            end

            assert_equal "Cannot construct an instance of the abstract class Zemu::Config::Memory.", e.message
        end
    end
end