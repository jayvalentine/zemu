#include "debug.h"

#include <stdio.h>

RunState zemu_debug_state = UNDEFINED;

/* Currently, the number of breakpoints is defined statically.
 * Perhaps in future there will be an unlimited number.
 */
zuint16 breakpoints[ZEMU_DEBUG_MAX_BREAKPOINTS];
unsigned int breakpoint_count = 0;

zusize zemu_debug_continue(Z80 * instance)
{
    /* Return if we've halted. */
    if (zemu_debug_state == HALTED) return 0;
 
    zusize cycles = 0;

    zemu_debug_state = RUNNING;

    while (zemu_debug_state == RUNNING)
    {
        cycles += zemu_debug_step(instance);

        /* See if the Program Counter now matches any address
         * in the breakpoint array.
         */
        for (unsigned int b = 0; b < breakpoint_count; b++)
        {
            if (instance->state.pc == breakpoints[b])
            {
                zemu_debug_state = BREAK;
            }
        }
    }

    return cycles;
}

zusize zemu_debug_step(Z80 * instance)
{
    /* Will run for at least one cycle. */
    zusize cycles = z80_run(instance, 1);

    return cycles;
}

void zemu_debug_halt(void * context, zboolean state)
{
    if (state)
    {
        zemu_debug_state = HALTED;
    }
    else
    {
        zemu_debug_state = RUNNING;
    }
}

void zemu_debug_set_breakpoint(zuint16 address)
{
    breakpoints[breakpoint_count] = address;
    breakpoint_count++;
}

zuint16 zemu_debug_register(Z80 * instance, zuint16 r)
{
    switch (r)
    {
        case 0:
            return instance->state.pc;
        default:
            return 0xFFFF;
    }
}

zboolean zemu_debug_halted(void)
{
    return (zemu_debug_state == HALTED);
}

zboolean zemu_debug_break(void)
{
    return (zemu_debug_state == BREAK);
}
