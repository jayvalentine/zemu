require 'minitest/autorun'
require 'zemu'

module Config
    # Tests the compiler property of the configuration object.
    class CompilerTest < Minitest::Test
        # The default compiler is clang. We expect it on the path, so no absolute
        # path is given.
        def test_default
            conf = Zemu::Config.new do
                name "my_config"
            end

            assert_equal "clang", conf.compiler
        end

        # We can set the compiler to something that isn't clang.
        def test_set
            conf = Zemu::Config.new do
                name "my_config"
                compiler "gcc"
            end

            assert_equal "gcc", conf.compiler
        end

        # We can set the compiler to an absolute path.
        # The path doesn't have to exist.
        def test_set_path_absolute
            conf = Zemu::Config.new do
                name "my_config"
                compiler "/path/doesnt/exist"
            end

            assert_equal "/path/doesnt/exist", conf.compiler
        end

        # We can set the compiler to a relative path.
        # The path doesn't have to exist.
        def test_set_path_relative
            conf = Zemu::Config.new do
                name "my_config"
                compiler "../total/garbage"
            end

            assert_equal "../total/garbage", conf.compiler
        end

        # The compiler parameter should be readonly once the configuration object has been initialized.
        def test_readonly_once_initialized
            conf = Zemu::Config.new do
                name "my_config"
                compiler "gcc"
            end

            assert_raises NoMethodError do
                conf.compiler "clang"
            end
        end
    end
end