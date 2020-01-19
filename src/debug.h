#include "emulation/CPU/Z80.h"

/* Define number of breakpoints, if not done so already. */
#ifndef ZEMU_DEBUG_MAX_BREAKPOINTS
#define ZEMU_DEBUG_MAX_BREAKPOINTS 256
#endif

typedef enum RunState
{
    RUNNING,
    HALTED,
    UNDEFINED
} RunState;

zusize zemu_debug_continue(Z80 * instance);

zusize zemu_debug_step(Z80 * instance);

void zemu_debug_halt(void * context, zboolean state);

zboolean zemu_debug_halted(void);

void zemu_debug_set_breakpoint(zuint16 address);
