require 'minitest/autorun'
require 'zemu'

class DriveTest < Minitest::Test
    BIN = File.join(__dir__, "..", "..", "bin")

    def teardown
        @instance.quit unless @instance.nil?
    end

    def asm(string)
        # Write the string to a temporary asm file.
        File.open(File.join(BIN, "temp.asm"), "w+") { |f| f.puts string }

        # Assemble.
        `vasmz80_oldstyle -Fbin -o #{File.join(BIN, "temp.bin")} #{File.join(BIN, "temp.asm")}`
    end

    # Test that after initializing the emulator instance,
    # we can get the initial state of the drive via the FFI function.
    def test_initial_state
        # Assemble the test program.
        asm <<-eos
    org     $0000
start:
    jp      start

eos

        # Write a binary file.
        File.open("file.bin", "wb") do |f|
            64.times do |sector|
                512.times do |offset|
                    # Some bytes in specific locations.
                    # All other bytes 0s.

                    byte = if (sector == 0 && offset == 12)
                        22
                    elsif (sector == 1 && offset == 42)
                        23
                    elsif (sector == 44 && offset == 511)
                        24
                    elsif (sector == 63 && offset == 0)
                        25
                    else
                        26
                    end

                    f.write [byte].pack("C")
                end
            end
        end

        conf = Zemu::Config.new do
            name "zemu_drive"

            output_directory BIN

            add_memory (Zemu::Config::ROM.new do
                name "rom"
                address 0x0000
                size 0x1000

                contents from_binary(File.join(BIN, "temp.bin"))
            end)

            add_io (Zemu::Config::BlockDrive.new do
                name "block_drive"
                base_port 0x00
                sector_size 512
                num_sectors 64

                initialize_from "file.bin"
            end)
        end

        @instance = Zemu.start(conf)

        # Check bytes in specific positions.
        assert_equal 22, @instance.drive_readbyte(0, 12)
        assert_equal 23, @instance.drive_readbyte(1, 42)
        assert_equal 24, @instance.drive_readbyte(44, 511)
        assert_equal 25, @instance.drive_readbyte(63, 0)

        assert_equal 26, @instance.drive_readbyte(0, 0)
        assert_equal 26, @instance.drive_readbyte(13, 13)
        assert_equal 26, @instance.drive_readbyte(9, 511)
    end

    # Test that an emulated CPU can access sectors of a block device.
    def test_read_sectors
        # Assemble the test program.
        asm <<-eos
    org     $0000
start:
    ; Sector count
    ld      A, $01
    out     ($12), A

    ; Wait for command ready
wait_rdy_1:
    in      A, ($17)
    and     %11000000
    xor     %01000000
    jp      nz, wait_rdy_1

    ; Sector 0
    ld      A, $00
    out     ($13), A
    ld      A, $00
    out     ($14), A
    ld      A, $00
    out     ($15), A
    ld      A, $e0
    out     ($16), A

    ; Read command
    ld      A, $20
    out     ($17), A

    ; Wait for data ready
wait_data_rdy_1:
    in      A, ($17)
    and     %10001000
    xor     %00001000
    jp      nz, wait_data_rdy_1

    ; Load data from sector into RAM
    ld      HL, $8000
    ld      C, $10
    ld      B, $00
    inir
    inir

    ; Wait for command ready
wait_rdy_2:
    in      A, ($17)
    and     %11000000
    xor     %01000000
    jp      nz, wait_rdy_2

    ; Sector 23240
    ld      A, %11001000
    out     ($13), A
    ld      A, %01011010
    out     ($14), A
    ld      A, $00
    out     ($15), A
    ld      A, $e0
    out     ($16), A

    ; Read command
    ld      A, $20
    out     ($17), A

    ; Wait for data ready
wait_data_rdy_2:
    in      A, ($17)
    and     %10001000
    xor     %00001000
    jp      nz, wait_data_rdy_2

    ; Load data from sector into RAM
    ld      HL, $9000
    ld      C, $10
    ld      B, $00
    inir
    inir

end:
    halt

eos

        # Write a binary file.
        File.open("file2.bin", "wb") do |f|
            24000.times do |sector|
                512.times do |offset|
                    # Some bytes in specific locations.
                    # All other bytes 0s.

                    byte = if (sector == 0 && offset == 12)
                        22
                    elsif (sector == 23240 && offset == 42)
                        23
                    else
                        26
                    end

                    f.write [byte].pack("C")
                end
            end
        end

        conf = Zemu::Config.new do
            name "zemu_drive_read"

            output_directory BIN

            add_memory (Zemu::Config::ROM.new do
                name "rom"
                address 0x0000
                size 0x1000

                contents from_binary(File.join(BIN, "temp.bin"))
            end)
            
            add_memory (Zemu::Config::RAM.new do
                name "ram"
                address 0x8000
                size 0x2000
            end)

            add_io (Zemu::Config::BlockDrive.new do
                name "block_drive"
                base_port 0x10
                sector_size 512
                num_sectors 24000

                initialize_from "file2.bin"
            end)
        end

        @instance = Zemu.start(conf)

        # Run until halt.
        @instance.continue 10000000
        assert @instance.halted?, "Program did not halt. (at address %04x)" % @instance.registers["PC"]

        # Check bytes in specific positions.
        assert_equal 22, @instance.memory(0x8000 + 12)
        assert_equal 23, @instance.memory(0x9000 + 42)

        assert_equal 26, @instance.memory(0x8000)
        assert_equal 26, @instance.memory(0x8001)
        assert_equal 26, @instance.memory(0x80ff)
        assert_equal 26, @instance.memory(0x81ff)

        assert_equal 26, @instance.memory(0x9000)
        assert_equal 26, @instance.memory(0x9001)
        assert_equal 26, @instance.memory(0x90ff)
        assert_equal 26, @instance.memory(0x91ff)
    end

    # Test that an emulated CPU can write sectors of a block device.
    def test_write_sectors
        # Assemble the test program.
        asm <<-eos
    org     $0000
start:
    ; Sector count
    ld      A, $01
    out     ($12), A

    ; Wait for command ready
wait_rdy_1:
    in      A, ($17)
    and     %11000000
    xor     %01000000
    jp      nz, wait_rdy_1

    ; Sector 0
    ld      A, $00
    out     ($13), A
    ld      A, $00
    out     ($14), A
    ld      A, $00
    out     ($15), A
    ld      A, $e0
    out     ($16), A

    ; Read command
    ld      A, $20
    out     ($17), A

    ; Wait for data ready
wait_data_rdy_1:
    in      A, ($17)
    and     %10001000
    xor     %00001000
    jp      nz, wait_data_rdy_1

    ; Load data from sector into RAM
    ld      HL, $8000
    ld      C, $10
    ld      B, $00
    inir
    inir

    ; Wait for command ready
wait_rdy_2:
    in      A, ($17)
    and     %11000000
    xor     %01000000
    jp      nz, wait_rdy_2

    ; Sector 2242
    ld      A, %11000010
    out     ($13), A
    ld      A, %00001000
    out     ($14), A
    ld      A, $00
    out     ($15), A
    ld      A, $e0
    out     ($16), A

    ; Write command
    ld      A, $30
    out     ($17), A

    ; Wait for data ready
wait_data_rdy_2:
    in      A, ($17)
    and     %10001000
    xor     %00001000
    jp      nz, wait_data_rdy_2

    ; Write data from RAM to drive.
    ld      HL, $8000
    ld      C, $10
    ld      B, $00
    otir
    otir

    ; Wait for command ready
wait_rdy_3:
    in      A, ($17)
    and     %11000000
    xor     %01000000
    jp      nz, wait_rdy_3

    ; Sector 23240
    ld      A, %11001000
    out     ($13), A
    ld      A, %01011010
    out     ($14), A
    ld      A, $00
    out     ($15), A
    ld      A, $e0
    out     ($16), A

    ; Read command
    ld      A, $20
    out     ($17), A

    ; Wait for data ready
wait_data_rdy_3:
    in      A, ($17)
    and     %10001000
    xor     %00001000
    jp      nz, wait_data_rdy_3

    ; Load data from sector into RAM
    ld      HL, $9000
    ld      C, $10
    ld      B, $00
    inir
    inir

    ; Wait for command ready
wait_rdy_4:
    in      A, ($17)
    and     %11000000
    xor     %01000000
    jp      nz, wait_rdy_4

    ; Sector 633
    ld      A, %01111001
    out     ($13), A
    ld      A, %00000010
    out     ($14), A
    ld      A, $00
    out     ($15), A
    ld      A, $e0
    out     ($16), A

    ; Write command
    ld      A, $30
    out     ($17), A

    ; Wait for data ready
wait_data_rdy_4:
    in      A, ($17)
    and     %10001000
    xor     %00001000
    jp      nz, wait_data_rdy_4

    ; Write data from RAM to drive.
    ld      HL, $9000
    ld      C, $10
    ld      B, $00
    otir
    otir

end:
    halt

eos

        # Write a binary file.
        File.open("file3.bin", "wb") do |f|
            24000.times do |sector|
                512.times do |offset|
                    # Some bytes in specific locations.
                    # All other bytes 0s.

                    byte = if (sector == 0 && offset == 12)
                        22
                    elsif (sector == 23240 && offset == 42)
                        23
                    else
                        26
                    end

                    f.write [byte].pack("C")
                end
            end
        end

        conf = Zemu::Config.new do
            name "zemu_drive_write"

            output_directory BIN

            add_memory (Zemu::Config::ROM.new do
                name "rom"
                address 0x0000
                size 0x1000

                contents from_binary(File.join(BIN, "temp.bin"))
            end)
            
            add_memory (Zemu::Config::RAM.new do
                name "ram"
                address 0x8000
                size 0x2000
            end)

            add_io (Zemu::Config::BlockDrive.new do
                name "block_drive"
                base_port 0x10
                sector_size 512
                num_sectors 24000

                initialize_from "file3.bin"
            end)
        end

        @instance = Zemu.start(conf)

        # Run until halt.
        @instance.continue 10000000
        assert @instance.halted?, "Program did not halt. (at address %04x)" % @instance.registers["PC"]

        # Load file for drive and assert that the contents
        # are as we expect.
        File.open("file3.bin", "rb") do |f|
            24000.times do |sector|
                512.times do |offset|
                    # Some bytes in specific locations.
                    # All other bytes 0s.

                    expected_byte = if (sector == 0 && offset == 12)
                        22
                    elsif (sector == 2242 && offset == 12)
                        22
                    elsif (sector == 23240 && offset == 42)
                        23
                    elsif (sector == 633 && offset == 42)
                        23
                    else
                        26
                    end

                    byte = f.getbyte
                    assert_equal expected_byte, byte, "Failed assert in sector #{sector}, offset #{offset}"
                end
            end
        end
    end
end
