require 'minitest/autorun'
require 'zemu'

module Config
    # Tests the name property of the configuration object.
    class NameTest < Minitest::Test
        # The configuration name can be set during initialization and later accessed.
        def test_set
            conf = Zemu::Config.new do |c|
                c.name = "my_config"
            end

            assert_equal "my_config", conf.name
        end

        # An exception is raised if the configuration name is empty after initialization is
        # complete.
        def test_set_empty
            e = assert_raises Zemu::ConfigError do
                _ = Zemu::Config.new do |c|
                    c.name = ""
                end
            end

            assert_equal "The name parameter of a Zemu::Config configuration object cannot be empty.", e.message
        end

        # An exception is raised if the configuration name is not set during initialization.
        def test_not_set
            e = assert_raises Zemu::ConfigError do
                _ = Zemu::Config.new do |c|
                end
            end

            assert_equal "The name parameter of a Zemu::Config configuration object must be set.", e.message
        end

        # An exception is raised if the configuration name contains whitespace after initialization.
        def test_set_whitespace
            e = assert_raises Zemu::ConfigError do
                _ = Zemu::Config.new do |c|
                    c.name = "my config"
                end
            end

            assert_equal "The name parameter of a Zemu::Config configuration object cannot contain whitespace.", e.message
        end

        # An exception is raised if the configuration contains a newline after initialization.
        def test_set_newline
            e = assert_raises Zemu::ConfigError do
                _ = Zemu::Config.new do |c|
                    c.name = "my\nconfig"
                end
            end

            assert_equal "The name parameter of a Zemu::Config configuration object cannot contain whitespace.", e.message
        end

        # The name parameter should be readonly once the configuration object has been initialized.
        def test_readonly_once_initialized
            conf = Zemu::Config.new do |c|
                c.name = "my_config"
            end

            assert_raises NoMethodError do
                conf.name = "your_config"
            end
        end
    end
end