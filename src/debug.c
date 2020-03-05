#include "debug.h"

zboolean halted = FALSE;

zusize zemu_debug_step(Z80 * instance)
{
    /* Will run for at least one cycle. */
    zusize cycles = z80_run(instance, 1);

    /* Execute the per-cycle behaviour of the peripheral devices. */
    for (zusize i = 0; i < cycles; i++) zemu_io_clock(instance);

    return cycles;
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

zuint16 zemu_debug_pc(Z80 * instance)
{
    return instance->state.pc;
}

void zemu_debug_halt(void * context, zboolean state)
{
    halted = state;
}

zboolean zemu_debug_halted(void)
{
    return (halted);
}

zuint8 zemu_debug_get_memory(zuint16 address)
{
    return zemu_memory_peek(address);
}
