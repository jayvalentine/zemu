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

    # Ensure that an appropriate error is raised on a malformed symbol.
    def test_parse_malformed
        e = assert_raises ArgumentError do
            sym = Zemu::Debug::Symbol.parse("sym =")
        end

        assert_equal "Invalid symbol definition: 'sym ='", e.message
    end

    # Ensure that an invalid address raises an exception.
    def test_parse_invalid_address
        e = assert_raises ArgumentError do
            sym = Zemu::Debug::Symbol.parse("sym = fred")
        end

        assert_equal "Invalid symbol address: 'fred'", e.message
    end

    # Ensure that we can handle an address in $hex format
    def test_hex_alternate_format
        sym = Zemu::Debug::Symbol.parse("sym = $ffed")
        assert_equal 0xffed, sym.address
    end

    # Ensure that we can handle an address in decimal format
    def test_decimal
        sym = Zemu::Debug::Symbol.parse("sym = 1000")
        assert_equal 1000, sym.address
    end

    # Ensures we can process a symbol using a custom format
    def test_custom_0x
        sym = Zemu::Debug::Symbol.parse("[0x1234] mysym") do |s|
            s = s.split
            label = s[1]
            address = nil
            if /\[(.+)\]/ =~ s[0]
                address = $1
            end

            [label, address]
        end

        assert_equal "mysym", sym.label
        assert_equal 0x1234, sym.address
    end

    # Ensures we can process a symbol using a custom format
    def test_custom_dollar
        sym = Zemu::Debug::Symbol.parse("[$1234] mysym") do |s|
            s = s.split
            label = s[1]
            address = nil
            if /\[(.+)\]/ =~ s[0]
                address = $1
            end

            [label, address]
        end

        assert_equal "mysym", sym.label
        assert_equal 0x1234, sym.address
    end

    # Ensures we can process a symbol using a custom format
    def test_custom_decimal
        sym = Zemu::Debug::Symbol.parse("[4567] mysym") do |s|
            s = s.split
            label = s[1]
            address = nil
            if /\[(.+)\]/ =~ s[0]
                address = $1
            end

            [label, address]
        end

        assert_equal "mysym", sym.label
        assert_equal 4567, sym.address
    end
end
