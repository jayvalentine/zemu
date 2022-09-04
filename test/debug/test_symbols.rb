require 'minitest/autorun'
require 'zemu'

class SymbolsTest < Minitest::Test
    def test_merge
        symbols1 = Zemu::Debug::Symbols.new([
            Zemu::Debug::Symbol.new("bob", 1000)
        ])

        symbols2 = Zemu::Debug::Symbols.new([
            Zemu::Debug::Symbol.new("alice", 123)
        ])

        assert_equal 1, symbols1.size
        assert_equal 1, symbols2.size

        assert_equal 1000, symbols1.find_by_name("bob").address
        assert_equal 123, symbols2.find_by_name("alice").address

        symbols1.merge! symbols2

        assert_equal 2, symbols1.size
        assert_equal 1, symbols2.size

        assert_equal 1000, symbols1.find_by_name("bob").address
        assert_equal 123, symbols1.find_by_name("alice").address

        assert_equal 123, symbols2.find_by_name("alice").address
    end
end