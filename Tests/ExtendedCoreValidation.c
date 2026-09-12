// SPDX-License-Identifier: GPL-2.0-or-later
#include "ExtendedCore.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dlfcn.h>
static void check(int ok) {
    if (ok) return;
    char error[2048]; ME_CopyError(error, sizeof(error));
    fprintf(stderr, "Extended validation failed: %s\n", error); exit(1);
}
static ME_Thing target(void) {
    ME_Thing things[128]; size_t count = ME_CopyThings(things, 128);
    assert(count <= 128);
    for (size_t i = 0; i < count; i++) if (things[i].editor_number == 9500) return things[i];
    assert(!"Missing patched actor"); return (ME_Thing){0};
}
int main(int argc, char **argv) {
    assert(argc >= 4);
    const char *mode = argv[1];
    ME_Config config = {ME_ABI_VERSION, (const char *const *)argv + 3, (uint32_t)(argc - 3), argv[2], 3, 1, 1993, 0, ME_PROFILE_MBF21};
    int initialized = ME_Init(&config);
    if (!strcmp(mode, "reject")) {
        assert(!initialized); char error[2048]; ME_CopyError(error, sizeof(error));
        assert(error[0]); printf("PASS rejection: %s\n", error);
        ME_Snapshot s; assert(!ME_CopySnapshot(&s)); assert(!ME_Init(&config)); return 0;
    }
    check(initialized);
    assert(dlsym(RTLD_DEFAULT, "P_Ticker") == NULL);
    assert(dlsym(RTLD_DEFAULT, "states") == NULL);
    ME_Snapshot before, after; check(ME_CopySnapshot(&before));
    assert(before.compatibility == 221);
    ME_Command command = {0};
    if (!strcmp(mode, "bad-actor") || !strcmp(mode, "bad-weapon")) {
        command.buttons = 1;
        int failed = 0;
        for (int i = 0; i < 70; i++) if (!ME_Tick(&command)) { failed = 1; break; }
        assert(failed); char error[2048]; ME_CopyError(error, sizeof(error));
        assert(strstr(error, "signature mismatch")); assert(!ME_CopySnapshot(&after));
        printf("PASS %s: %s\n", mode, error); return 0;
    }
    if (!strcmp(mode, "combat")) {
        ME_Thing initial = target(); assert(initial.health == 200);
        assert(before.state_count > 1076);
        for (int i = 0; i < 35; i++) check(ME_Tick(&command));
        ME_Thing active = target(); assert(active.flags & 512); assert(active.flags2 & 1);
        command.buttons = 1; check(ME_Tick(&command));
        command.buttons = 0;
        for (int i = 0; i < 10; i++) check(ME_Tick(&command));
        check(ME_CopySnapshot(&after));
        assert(after.ammo[0] == before.ammo[0] - 2);
        ME_Thing hit = target(); assert(hit.health == 193);
        printf("PASS combat: states=%u types=%u target=%d->%d ammo=%d->%d flags=%u/%u\n",
            after.state_count, after.thing_type_count, initial.health, hit.health,
            before.ammo[0], after.ammo[0], hit.flags, hit.flags2);
    } else {
        command.forward_move = !strcmp(mode, "conveyor") ? 0 : 25;
        for (int i = 0; i < 35; i++) check(ME_Tick(&command));
        check(ME_CopySnapshot(&after));
        assert(after.tic == before.tic + 35);
        assert(after.x != before.x || after.y != before.y);
        if (!strcmp(mode, "conveyor")) assert(after.y > before.y && after.x == before.x);
        printf("PASS movement: tic=%u x=%d y=%d health=%d actors=%zu\n", after.tic, after.x, after.y, after.health, ME_CopyThings(NULL, 0));
    }
    ME_Thing all[512]; size_t count = ME_CopyThings(all, 512); assert(count <= 512);
    uint64_t digest = UINT64_C(14695981039346656037);
    const unsigned char *bytes = (const unsigned char *)all;
    for (size_t i = 0; i < count * sizeof(*all); i++) { digest ^= bytes[i]; digest *= UINT64_C(1099511628211); }
    printf("Actor snapshot digest: %016llx\n", (unsigned long long)digest);
    assert(!ME_Init(&config));
    return 0;
}
