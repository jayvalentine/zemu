module Zemu
    # Handles debugging functionality, like mapping of symbols to addresses,
    # disassembling of instructions, etc.
    module Debug
        # Loads a map file at the given path, and returns a hash of address => Symbol
        # for the symbols defined within.
        def self.load_map(path)
            symbols = []

            File.open(path, "r") do |f|
                f.each_line do |l|
                    s = Symbol.parse(l)

                    symbols << s unless s.nil?
                end
            end

            return Symbols.new(symbols)
        end

        # Contains a set of symbols.
        # Allows for various lookup operations.
        class Symbols
            attr_reader :syms
            
            # Constructor.
            def initialize(syms)
                @syms = []
                syms.each do |s|
                    @syms << s
                end
            end

            def size
                @syms.size
            end

            # Access all symbols with a given address.
            def [](address)
                at_address = []
                @syms.each do |s|
                    if s.address == address
                        at_address << s
                    end
                end

                return at_address.sort_by(&:label)
            end

            # Find a symbol with a given name.
            def find_by_name(name)
                @syms.each do |s|
                    return s if s.label == name
                end

                return nil
            end

            def merge!(other)
                other.syms.each do |s|
                    @syms << s
                end
            end
        end
        
        # Represents a symbol definition, of the form `label = address`.
        class Symbol
            # Parse a symbol definition, returning a Symbol instance.
            def self.parse(s, &block)
                label = nil
                address = nil

                label, address_string = if block_given?
                    block.call(s)
                else
                    # Split on whitespace.
                    tokens = s.to_s.split(' ')

                    if tokens.size < 3
                        raise ArgumentError, "Invalid symbol definition: '#{s}'"
                    end

                    [tokens[0], tokens[2]]
                end

                if /0x[0-9a-fA-F]+/ =~ address_string
                     address = address_string.to_i(16)
                elsif /\$[0-9a-fA-F]+/ =~ address_string
                    address = address_string[1..-1].to_i(16)
                elsif /\d+/ =~ address_string
                    address = address_string.to_i
                end
 
                if address.nil?
                    raise ArgumentError, "Invalid symbol address: '#{address_string}'"
                end

                return self.new(label, address)
            end

            # Textual label for this symbol.
            attr_reader :label

            # Address of this symbol in the binary.
            attr_reader :address

            def initialize(label, address)
                @label = label
                @address = address
            end
        end
    end
end
