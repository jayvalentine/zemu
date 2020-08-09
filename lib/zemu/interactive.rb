module Zemu
    # An interactive instance of a Zemu emulator.
    # Wraps a Zemu::Instance to allow for user input and debugging.
    class InteractiveInstance
        # Constructor.
        #
        # Create a new interactive wrapper for the given instance.
        def initialize(instance)
            @instance = instance

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

                elsif cmd[0] == "help"
                    log "Available commands:"
                    log "    continue [<n>]     - Continue execution for <n> cycles"
                    log "    step               - Step over a single instruction"
                    log "    registers          - View register contents"
                    log "    memory <a> [<n>]   - View <n> bytes of memory, starting at address <a>."
                    log "                         <n> defaults to 1 if omitted."
                    log "    break  <a>         - Set a breakpoint at the given address <a>."
                    log "    quit               - End this emulator instance."

                else
                    log "Invalid command. Type 'help' for available commands."
                    
                end
            end

            close
        end

        # Outputs a table giving the current values of the instance's registers.
        def registers
            log "A:  #{r("A")} F: #{r("F")}"
            log "B:  #{r("B")} C: #{r("C")}"
            log "D:  #{r("D")} E: #{r("E")}"
            log "H:  #{r("H")} L: #{r("L")}"
            log ""
            log "IX: #{r16("IX")}"
            log "IY: #{r16("IY")}"
            log "SP: #{r16("SP")}"
            log "PC: #{r16("PC")}"
        end

        # Returns a particular 8-bit register value.
        def r(reg)
            return "0x%02x" % @instance.registers[reg]
        end

        # Returns a particular 16-bit register value.
        def r16(reg)
            return "0x%04x" % @instance.registers[reg]
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

            serial_count = 0.001042

            while ((cycles == -1) || (cycles_left > 0))
                # Get time before execution.
                start = Time.now

                old_pc = r16("PC")

                if (serial_count >= 0.001042)
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

                    execution_time = cycles_done * (1/@instance.clock_speed)
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