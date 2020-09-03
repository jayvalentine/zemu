module Zemu
    # An interactive instance of a Zemu emulator.
    # Wraps a Zemu::Instance to allow for user input and debugging.
    class InteractiveInstance
        # Constructor.
        #
        # Create a new interactive wrapper for the given instance.
        def initialize(instance)
            @instance = instance

            @symbol_table = {}

            @master, @slave = PTY.open
            log "Opened PTY at #{@slave.path}"
        end

        # Logs a message to the user output.
        def log(message)
            STDOUT.puts "    " + message
        end

        # Close the interactive wrapper
        def close
            @master.close
            @slave.close
            @instance.quit
        end

        # Run the interactive emulator until the user exits.
        def run
            quit = false

            until quit
                print "ZEMU> "
                # Get a command from the user.
                cmd = STDIN.gets.split

                if cmd[0] == "quit"
                    quit = true

                elsif cmd[0] == "continue"
                    if cmd[1].nil?
                        continue
                    else
                        continue(cmd[1].to_i)
                    end

                elsif cmd[0] == "step"
                    continue(1)

                elsif cmd[0] == "registers"
                    registers

                elsif cmd[0] == "break"
                    add_breakpoint(cmd[1])

                elsif cmd[0] == "memory"
                    if cmd[2].nil?
                        memory(cmd[1])
                    else
                        memory(cmd[1], cmd[2])
                    end

                elsif cmd[0] == "map"
                    load_map(cmd[1])

                elsif cmd[0] == "help"
                    log "Available commands:"
                    log "    continue [<n>]     - Continue execution for <n> cycles"
                    log "    step               - Step over a single instruction"
                    log "    registers          - View register contents"
                    log "    memory <a> [<n>]   - View <n> bytes of memory, starting at address <a>."
                    log "                         <n> defaults to 1 if omitted."
                    log "    map <path>         - Load symbols from map file at <path>"
                    log "    break  <a>         - Set a breakpoint at the given address <a>."
                    log "    quit               - End this emulator instance."

                else
                    log "Invalid command. Type 'help' for available commands."
                    
                end
            end

            close
        end

        # Outputs a table giving the current values of the instance's registers.
        # For the 16-bit registers (BC, DE, HL, IX, IY, SP, PC), attempts to identify the symbol
        # to which they point.
        def registers
            log "A:  #{r("A")} F: #{r("F")}"

            registers_gp('B', 'C')
            registers_gp('D', 'E')
            registers_gp('H', 'L')

            log ""

            register_16("IX")
            register_16("IY")
            register_16("SP")
            register_16("PC")
        end

        # Displays the value of a 16-bit register.
        def register_16(r)
            value = @instance.registers[r]

            log "#{r}: #{r16(r)} (#{get_symbol(value)})"
        end

        # Displays the value of a general-purpose 16-bit register pair.
        def registers_gp(hi, lo)
            value = hilo(@instance.registers[hi], @instance.registers[lo])

            log "#{hi}:  #{r(hi)} #{lo}: #{r(lo)} (#{get_symbol(value)})"
        end

        def get_symbol(value)
            syms = nil
            addr = value
            while addr > 0 do
                syms = @symbol_table[addr]
                break unless syms.nil?
                addr -= 1
            end

            sym = if syms.nil? then nil else syms[0] end

            sym_str = "<#{if sym.nil? then 'undefined' else sym.label end}#{if addr == value then '' else "+#{value-addr}" end}>"

            return sym_str
        end

        # Returns a particular 8-bit register value.
        def r(reg)
            return "0x%02x" % @instance.registers[reg]
        end

        # Returns a particular 16-bit register value.
        def r16(reg)
            return "0x%04x" % @instance.registers[reg]
        end

        # Concatenates two 8-bit values, in big-endian format.
        def hilo(hi, lo)
            return (hi << 8) | lo
        end

        # Continue for *up to* the given number of cycles.
        # Fewer cycles may be executed, depending on the behaviour of the processor.
        def continue(cycles=-1)
            if cycles == 0
                log "Invalid value: #{cycles}"
                return
            end

            # Continue executing instruction-by-instruction.
            # Process IO in-between.
            cycles_left = cycles
            actual_cycles = 0

            serial_count = @instance.serial_delay

            while ((cycles == -1) || (cycles_left > 0))
                # Get time before execution.
                start = Time.now

                old_pc = r16("PC")

                if (serial_count >= @instance.serial_delay)
                    process_serial
                    serial_count = 0
                end

                cycles_done = @instance.continue(1)
                cycles_left -= cycles_done
                actual_cycles += cycles_done

                # Get time after execution.
                ending = Time.now

                # Get elapsed time and calculate padding time to match clock speed.
                if @instance.clock_speed > 0
                    elapsed = ending - start

                    execution_time = cycles_done * (1.0/@instance.clock_speed)
                    serial_count += execution_time
                    
                    padding = execution_time - elapsed
                    sleep(padding) unless padding < 0
                end

                # Have we hit a breakpoint or HALT instruction?
                if @instance.break?
                    log "Hit breakpoint at #{r16("PC")}."
                    break
                elsif @instance.halted?
                    log "Executed HALT instruction at #{old_pc}."
                    break
                end
            end

            log "Executed for #{actual_cycles} cycles."
        end

        # Add a breakpoint at the address given by the string.
        def add_breakpoint(addr_str)
            @instance.break(addr_str.to_i(16), :program)
        end

        # Dump an amount of memory.
        def memory(address, size="1")
            if address.nil?
                log "Expected an address, got #{address}."
                return
            end

            if (address.to_i(16) < 1 || address.to_i(16) > 0xffff)
                log "Invalid address: 0x%04x" % address.to_i(16)
                return
            end
            
            (address.to_i(16)...address.to_i(16) + size.to_i(16)).each do |a|
                m = @instance.memory(a)
                if (m < 32 || m > 126)
                    log "%04x: %02x    ." % [a, m]
                else
                    log ("%04x: %02x    " % [a, m]) + m.chr("UTF-8")
                end
            end
        end

        def load_map(path)
            if path.nil?
                log "No path specified."
                return
            end

            unless File.exist?(path.to_s)
                log "Map file '#{path}' does not exist."
                return
            end

            if File.directory?(path.to_s)
                log "Cannot open '#{path}': it is a directory."
                return
            end

            syms = {}
            begin
                syms.merge! Debug.load_map(path.to_s)
            rescue ArgumentError => e
                log "Error loading map file: #{e.message}"
                syms.clear
            end

            @symbol_table.merge! syms
        end

        # Process serial input/output via the TTY.
        def process_serial
            # Read/write serial.
            # Get the strings to be input/output.
            input = ""
            ready = IO.select([@master], [], [], 0)
            unless ready.nil? || ready.empty?
                input = @master.read(1)
            end

            output = @instance.serial_gets(1)

            unless input.empty?
                @instance.serial_puts input
                log "Serial in: #{input}"
            end

            unless output.empty?
                @master.write output
                log "Serial out: #{output}"
            end
        end
    end
end