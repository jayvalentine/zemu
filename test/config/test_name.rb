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
    end
end