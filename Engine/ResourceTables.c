// SPDX-License-Identifier: GPL-2.0-or-later
// Boom packed resource tables. Semantics checked against Woof p_spec/p_switch;
// bounded decoding and native integration are maintained here.
#include <stdint.h>
#include <string.h>
#include <strings.h>
#include "ResourceTables.h"
#include "i_system.h"
#include "w_wad.h"
#include "z_zone.h"
#include "r_data.h"
#include "r_state.h"

// A deliberate resource budget, independent of vanilla's 32/50 table sizes.
#define MAX_RESOURCE_RECORDS 65536

static int TableLump(const char *name, int stride, int *size) {
    int lump = W_CheckNumForName(name);
    if (lump < 0) return -1;
    *size = W_LumpLength(lump);
    if (*size < 1 || *size > stride * MAX_RESOURCE_RECORDS)
        I_Error("%s: invalid packed table size", name);
    return lump;
}
static void Name(char out[9], const byte *in, const char *table) {
    // On disk names occupy nine bytes, including a required terminator.
    if (in[8] || !in[0]) I_Error("%s: invalid resource name", table);
    memcpy(out, in, 8); out[8] = 0;
}
static int Flat(const char *name) {
    // Resolve in the flat namespace, never a same-named general lump.
    for (int i = numflats - 1; i >= 0; --i)
        if (!strncasecmp(lumpinfo[firstflat+i]->name, name, 8)) return i;
    return -1;
}
boolean MD_LoadAnimations(void) {
    int size, lump = TableLump("ANIMATED", 23, &size);
    if (lump < 0) return false;
    const byte *data = W_CacheLumpNum(lump, PU_STATIC);
    MD_EngineAnim *table = Z_Malloc(((size + 22) / 23) * sizeof(*table), PU_STATIC, NULL);
    int count = 0;
    boolean terminated = false;
    for (int offset = 0; offset < size; offset += 23) {
        const byte *row = data + offset;
        // Boom reads the first signed byte as the terminator; SIGIL II
        // pads that marker to four bytes rather than a full 23-byte record.
        if (row[0] == 255) { terminated = true; break; }
        if (size - offset < 23) I_Error("ANIMATED: truncated record");
        if (row[0] > 1) I_Error("ANIMATED: unsupported animation kind");
        char start[9], end[9];
        Name(end, row+1, "ANIMATED"); Name(start, row+10, "ANIMATED");
        uint32_t speed = (uint32_t)row[19] | (uint32_t)row[20]<<8
                       | (uint32_t)row[21]<<16 | (uint32_t)row[22]<<24;
        // SMMU distortion (>=65536), zero and negative speeds aren't Boom cycles.
        if (!speed || speed >= 65536) I_Error("ANIMATED: unsupported animation speed");
        int first = row[0] ? R_CheckTextureNumForName(start) : Flat(start);
        if (first < 0) continue; // Definitions for other IWADs are allowed.
        int last = row[0] ? R_CheckTextureNumForName(end) : Flat(end);
        if (last < first || last == first) I_Error("ANIMATED: invalid cycle %s to %s", start, end);
        table[count++] = (MD_EngineAnim){row[0], last, first, last-first+1, (int)speed};
    }
    if (!terminated) I_Error("ANIMATED: missing terminator");
    anims = table; lastanim = table + count;
    W_ReleaseLumpNum(lump);
    return true;
}
boolean MD_LoadSwitches(int episode) {
    int size, lump = TableLump("SWITCHES", 20, &size);
    if (lump < 0) return false;
    if (size % 20) I_Error("SWITCHES: truncated record");
    const byte *data = W_CacheLumpNum(lump, PU_STATIC);
    int *table = Z_Malloc(((size / 20)*2+1) * sizeof(*table), PU_STATIC, NULL);
    int count = 0;
    boolean terminated = false;
    for (int offset = 0; offset < size; offset += 20) {
        const byte *row = data + offset;
        int scope = row[18] | row[19]<<8;
        if (!scope) { terminated = true; break; }
        if (scope > 3) I_Error("SWITCHES: invalid game scope");
        char first[9], second[9];
        Name(first, row, "SWITCHES"); Name(second, row+9, "SWITCHES");
        if (scope > episode) continue;
        int a = R_CheckTextureNumForName(first), b = R_CheckTextureNumForName(second);
        // Shared resource packs may name textures unavailable in this IWAD.
        if (a < 0 || b < 0) continue;
        table[count++] = a; table[count++] = b;
    }
    if (!terminated) I_Error("SWITCHES: missing terminator");
    table[count] = -1; switchlist = table; numswitches = count / 2;
    W_ReleaseLumpNum(lump);
    return true;
}
