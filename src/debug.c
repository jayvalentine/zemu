#include "debug.h"

RunState zemu_debug_state = UNDEFINED;

/* Currently, the number of breakpoints is defined statically.
 * Perhaps in future there will be an unlimited number.
 */
zuint16 breakpoints[ZEMU_DEBUG_MAX_BREAKPOINTS];
unsigned int breakpoint_count = 0;

zusize zemu_debug_continue(Z80 * instance, zinteger run_cycles)
{
    /* Return if we've halted. */
    if (zemu_debug_state == HALTED) return 0;
 
    zusize cycles = 0;

    zemu_debug_state = RUNNING;

    /* Run as long as:
     * We don't hit a breakpoint
     * We haven't run for more than the number of cycles given
     */
    while (zemu_debug_state == RUNNING && (run_cycles < 0 || cycles < run_cycles))
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
        /* Special purpose registers. */
        case 0:     return instance->state.pc;
        case 1:     return instance->state.sp;
        case 2:     return instance->state.iy.value_uint16;
        case 3:     return instance->state.ix.value_uint16;

        /* Main register set, 8-bit format. */
        case 4:     return instance->state.af.values_uint8.index1;
        case 5:     return instance->state.af.values_uint8.index0;

        case 6:     return instance->state.bc.values_uint8.index1;
        case 7:     return instance->state.bc.values_uint8.index0;

        case 8:     return instance->state.de.values_uint8.index1;
        case 9:     return instance->state.de.values_uint8.index0;

        case 10:    return instance->state.hl.values_uint8.index1;
        case 11:    return instance->state.hl.values_uint8.index0;

        /* Alternate register set, 8-bit format. */
        case 12:    return instance->state.af_.values_uint8.index1;
        case 13:    return instance->state.af_.values_uint8.index0;

        case 14:    return instance->state.bc_.values_uint8.index1;
        case 15:    return instance->state.bc_.values_uint8.index0;

        case 16:    return instance->state.de_.values_uint8.index1;
        case 17:    return instance->state.de_.values_uint8.index0;

        case 18:    return instance->state.hl_.values_uint8.index1;
        case 19:    return instance->state.hl_.values_uint8.index0;

        default:    return 0xFFFF;
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

zuint8 zemu_debug_get_memory(zuint16 address)
{
    return zemu_memory_peek(address);
}
