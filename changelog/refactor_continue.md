### Improvement to Instance#continue

The Instance#continue method is now implemented directly in Ruby, rather than simply being
a wrapper around a C implementation. This will make it easier to extend debugging functionality
in the future.
