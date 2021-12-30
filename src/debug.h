#include "emulation/CPU/Z80.h"

#include <stdio.h>

#include "bus.h"

zusize zemu_debug_step(Z80 * instance);

void zemu_debug_halt(void * context, zboolean state);

zboolean zemu_debug_halted(void);
zboolean zemu_debug_break(void);
zboolean zemu_debug_running(void);

zuint16 zemu_debug_register(Z80 * instance, zuint16 r);

zuint16 zemu_debug_pc(Z80 * instance);
