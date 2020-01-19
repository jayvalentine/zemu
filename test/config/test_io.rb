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
    end
end