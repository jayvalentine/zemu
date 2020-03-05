#include "emulation/CPU/Z80.h"

#include <stdio.h>

#include "memory.h"
#include "io.h"

/* Define number of breakpoints, if not done so already. */
#ifndef ZEMU_DEBUG_MAX_BREAKPOINTS
#define ZEMU_DEBUG_MAX_BREAKPOINTS 256
#endif

zusize zemu_debug_step(Z80 * instance);

void zemu_debug_halt(void * context, zboolean state);

zboolean zemu_debug_halted(void);
zboolean zemu_debug_break(void);
zboolean zemu_debug_running(void);

void zemu_debug_set_breakpoint(zuint16 address);

zuint16 zemu_debug_register(Z80 * instance, zuint16 r);

zuint16 zemu_debug_pc(Z80 * instance);
