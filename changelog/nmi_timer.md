### Non-Maskable Interrupt Timer

The Timer IO device has been added. This device provides an 8-bit register to which the emulated
machine can write a count. The count decreases by 1 for every cycle executed, and generates an NMI
once expired.
