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
                elsif cmd[0] == "registers"
                    registers
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

            # Continue in blocks of 10 cycles,
            # to allow for processing of IO.
            cycles_left = cycles
            actual_cycles = 0

            done = false

            while ((cycles == -1) || (cycles_left > 0)) & !done
                process_serial
                cycles_done = @instance.continue(10)

                # If we ever execute fewer than 10 cycles it means
                # that something has happened, either a halt or a breakpoint.
                if cycles_done < 10
                    done = true
                end

                cycles_left -= cycles_done
                actual_cycles += cycles_done
            end

            log "Executed for #{actual_cycles} cycles."
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