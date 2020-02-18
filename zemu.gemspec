HERE = __dir__

MAJOR = 0
MINOR = 2
REFRESH = 0

DESCRIPTION = <<-eos
    Zemu is a gem which allows the user to configure a Z80-based system
    and then launch emulation instances of that system.
    These instances can be interacted with programmatically, allowing the
    user to inspect the contents of registers and memory, step, add breakpoints,
    and more.

    The gem requires the user to install a compatible C compiler.
    Currently the only compatible compiler is clang.

    Please report any issues on the GitHub page for the gem.
    This is accessible under "Homepage".
eos

Gem::Specification.new do |s|
    # This stuff will always be the same.
    s.name = 'zemu'
    s.summary = 'A configurable Z80 emulator.'
    s.description = DESCRIPTION

    s.authors = ['Jay Valentine']
    s.license = 'GPL-3.0'
    s.email = 'jayv136@gmail.com'
    s.homepage = 'https://github.com/jayvalentine/zemu'

    # This changes per-version.
    s.version = "#{MAJOR}.#{MINOR}.#{REFRESH}"
    s.date = Time.now.strftime("%Y-%m-%d")

    # If new directories not covered here are added,
    # you must ensure they are included when releasing.
    s.files = Dir.glob(File.join("lib", "**", "*.rb")) + Dir.glob(File.join("src", "**", "*.*"))
end
