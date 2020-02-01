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
            STDOUT.puts "Opened PTY at #{@slave.path}"
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
                print "ZEMU > "
                # Get a command from the user.
                cmd = STDIN.gets.split

                if cmd[0] == "quit"
                    quit = true
                elsif cmd[0] == "continue"
                    continue(cmd[1])
                end
            end

            close
        end

        # Continue for *up to* the given number of cycles.
        # Fewer cycles may be executed, depending on the behaviour of the processor.
        def continue(cycles_str)
            if cycles_str.nil? || (cycles_str.to_i == 0)
                STDOUT.puts "Invalid value: #{cycles_str}"
                return
            end

            # Continue in blocks of 10 cycles,
            # to allow for processing of IO.
            cycles = cycles_str.to_i
            actual_cycles = 0
            done = false

            while (cycles > 0) & !done
                process_serial
                cycles_done = @instance.continue(10)

                # If we ever execute fewer than 10 cycles it means
                # that something has happened, either a halt or a breakpoint.
                if cycles_done < 10
                    done = true
                end

                cycles -= cycles_done
                actual_cycles += cycles_done
            end

            STDOUT.puts "Executed for #{actual_cycles} cycles."
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
                STDOUT.puts "Serial in: #{input}"
            end

            unless output.empty?
                @master.write output
                STDOUT.puts "Serial out: #{output}"
            end
        end
    end
end