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

                    symbols << s
                end
            end

            return Symbols.new(symbols)
        end

        # Contains a set of symbols.
        # Allows for various lookup operations.
        class Symbols
            # Constructor.
            def initialize(syms)
                @syms = []
                syms.each do |s|
                    @syms << s
                end
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
        end
        
        # Represents a symbol definition, of the form `label = address`.
        class Symbol
            # Parse a symbol definition, returning a Symbol instance.
            def self.parse(s)
                # Split on whitespace.
                tokens = s.to_s.split(' ')

                if tokens.size < 3
                    raise ArgumentError, "Invalid symbol definition: '#{s}'"
                end

                label = tokens[0]

                address = nil

                if /0x[0-9a-fA-F]+/ =~ tokens[2]
                    address = tokens[2][2..-1].to_i(16)
                elsif /\$[0-9a-fA-F]+/ =~ tokens[2]
                    address = tokens[2][1..-1].to_i(16)
                elsif /\d+/ =~ tokens[2]
                    address = tokens[2].to_i
                end

                if address.nil?
                    raise ArgumentError, "Invalid symbol address: '#{tokens[2]}'"
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
