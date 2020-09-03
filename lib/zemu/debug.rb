module Zemu
    # Handles debugging functionality, like mapping of symbols to addresses,
    # disassembling of instructions, etc.
    module Debug
        # Loads a map file at the given path, and returns a hash of address => Symbol
        # for the symbols defined within.
        def self.load_map(path)
            symbols = {}

            File.open(path, "r") do |f|
                f.each_line do |l|
                    s = Symbol.parse(l)

                    if symbols[s.address].nil?
                        symbols[s.address] = []
                    end

                    symbols[s.address] << s
                    symbols[s.address].sort_by!(&:label)
                end
            end

            return symbols
        end
        
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
