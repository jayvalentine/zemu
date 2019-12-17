require 'minitest/autorun'
require 'zemu'

module Config
    # Tests the compiler property of the configuration object.
    class CompilerTest < Minitest::Test
        # The default compiler is clang. We expect it on the path, so no absolute
        # path is given.
        def test_default
            conf = Zemu::Config.new do |c|
                c.name = "my_config"
            end

            assert_equal "clang", conf.compiler
        end
    end
end