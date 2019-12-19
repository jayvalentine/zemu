#include "debug.h"

RunState zemu_debug_state = UNDEFINED;

zusize zemu_debug_continue(Z80 * instance)
{
    zusize cycles = 0;

    while (!zemu_debug_halted)
    {
        cycles += zemu_debug_step(instance);
    }

    return cycles;
}

zusize zemu_debug_step(Z80 * instance)
{
    /* Will run for at least one cycle. */
    return z80_run(instance, 1);
}

void zemu_debug_halt(void * context, zboolean state)
{
    if (state)  zemu_debug_state = HALTED;
    else        zemu_debug_state = RUNNING;
}

zboolean zemu_debug_halted(void)
{
    return (zemu_debug_state == HALTED);
}
