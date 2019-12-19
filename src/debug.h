#include "emulation/CPU/Z80.h"

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
