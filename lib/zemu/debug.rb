module Zemu
    # Handles debugging functionality, like mapping of symbols to addresses,
    # disassembling of instructions, etc.
    module Debug
        class Symbol
            # Parse a symbol definition, returning a Symbol instance.
            def self.parse(s)
                # Split on whitespace.
                tokens = s.split(' ')

                label = tokens[0]
                address = tokens[2][2..-1].to_i(16)

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
