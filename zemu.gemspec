HERE = __dir__

MAJOR = 0
MINOR = 1
REFRESH = 1

Gem::Specification.new do |s|
    # This stuff will always be the same.
    s.name = 'zemu'
    s.summary = 'zemu'
    s.description = 'A configurable Z80 emulator gem'
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
