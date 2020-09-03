require 'minitest/autorun'
require 'zemu'

class MapTest < Minitest::Test
    def test_load
        File.open("test.map", "w+") do |f|
            f.puts "symA = 0x1234"
            f.puts "symB      = $feed"
            f.puts "symC    = 20 ; This is a comment"
            f.puts "symD = $1234"
        end

        symbols = Zemu::Debug.load_map("test.map")

        # First, test the keys.
        assert symbols[0x1234] != nil
        assert symbols[0xfeed] != nil
        assert symbols[20] != nil

        assert_equal 2, symbols[0x1234].size
        assert_equal 1, symbols[0xfeed].size
        assert_equal 1, symbols[20].size

        # Check we have the symbols we expect.

        # Two symbols with same address should be sorted by label
        assert_equal "symA", symbols[0x1234][0].label
        assert_equal 0x1234, symbols[0x1234][0].address
        assert_equal "symD", symbols[0x1234][1].label
        assert_equal 0x1234, symbols[0x1234][1].address

        assert_equal "symB", symbols[0xfeed][0].label
        assert_equal 0xfeed, symbols[0xfeed][0].address

        assert_equal "symC", symbols[20][0].label
        assert_equal 20, symbols[20][0].address
    end
end

