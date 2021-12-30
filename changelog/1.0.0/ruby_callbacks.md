### Implementing device logic in Ruby

Device logic is now implemented in Ruby, rather than C.
The Ruby implementations are called via FFI callbacks at runtime.

This allows the definition of a system configuration, including
new devices, without having to write any C.
