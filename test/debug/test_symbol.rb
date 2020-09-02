require 'minitest/autorun'
require 'zemu'

# Tests the functionality of the symbol class.
class SymbolTest < Minitest::Test
    # Ensure that we can instanciate a new symbol.
    def test_new
        sym = Zemu::Debug::Symbol.new("sym", 0x1234)
        assert_equal "sym", sym.label
        assert_equal 0x1234, sym.address
    end

    # Ensure that we can parse a symbol from text form.
    def test_parse
        sym = Zemu::Debug::Symbol.parse("sym = 0x1234")
        assert_equal "sym", sym.label
        assert_equal 0x1234, sym.address
    end
end
