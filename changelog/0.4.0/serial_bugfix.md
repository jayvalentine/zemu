### Fixed bug in serial handling

A bug in the handling of serial communication when executing the `continue <n>` command in serial mode,
where the serial communication would be handled at most once, has been resolved.
