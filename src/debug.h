#include "emulation/CPU/Z80.h"

#include <stdio.h>

#include "memory.h"
#include "io.h"

/* Define number of breakpoints, if not done so already. */
#ifndef ZEMU_DEBUG_MAX_BREAKPOINTS
#define ZEMU_DEBUG_MAX_BREAKPOINTS 256
#endif

typedef enum RunState
{
    RUNNING = 0,
    HALTED = 1,
    BREAK = 2,
    UNDEFINED = -1
} RunState;

zusize zemu_debug_continue(Z80 * instance, zinteger run_cycles);

zusize zemu_debug_step(Z80 * instance);

void zemu_debug_halt(void * context, zboolean state);

zboolean zemu_debug_halted(void);

void zemu_debug_set_breakpoint(zuint16 address);

zuint16 zemu_debug_register(Z80 * instance, zuint16 r);
