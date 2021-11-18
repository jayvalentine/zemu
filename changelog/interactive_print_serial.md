### Added :print_serial option to InteractiveInstance

The `:print_serial` option can now be used when instantiating
an `InteractiveInstance` (and when calling `Zemu::start_interactive`)
to disable logging of serial I/O to the debug command window.

This option does not change how serial I/O is handled in
the PTY created by the interactive instance.
