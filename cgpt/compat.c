#include <stdarg.h>
#include <stdint.h>
#include <string.h>

#include "cgptlib.h"

/*
 * cgptlib_internal.c needs this helper, but upstream defines it in
 * gpt_misc.c.  Pulling in all of gpt_misc.c would also pull in the
 * firmware-oriented VbExDiskRead/VbExDiskWrite interface, which the
 * standalone cgpt utility does not use.
 */
int IsUnusedEntry(const GptEntry *e)
{
    static Guid zero = {{{0, 0, 0, 0, 0, {0, 0, 0, 0, 0, 0}}}};

    return !memcmp(&zero, (const uint8_t *)&e->type, sizeof(zero));
}

/*
 * vboot's GPT library expects a debug-printing hook.
 *
 * OTL does not need vboot debug logging, so intentionally discard it.
 * This function exists only to satisfy the C ABI expected by cgptlib.
 */
void vb2ex_printf(const char *func, const char *fmt, ...)
{
    (void)func;
    (void)fmt;
}
