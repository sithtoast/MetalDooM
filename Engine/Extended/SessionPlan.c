// SPDX-License-Identifier: GPL-2.0-or-later
// Restricted, explicit session planning for the native development worker.
// GAMECONF contracts: pinned ID24 0.99.2; see docs/LEGACY_OF_RUST.md.
#include "SessionPlan.h"
#include "i_system.h"
#include "doomstat.h"
#include "g_game.h"
#include <CommonCrypto/CommonDigest.h>
#include "yyjson.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <sys/stat.h>
#include <errno.h>
#include <ctype.h>

static ME_Session session;
static int comp_soul_value = -1;
static const char *base_name;
static const char *features[] = {"doom1.9", "limitremoving", "bugfixed", "boom2.02",
    "complevel9", "mbf", "mbf21", "mbf21ex", "id24"};
static uint32_t LE32(const unsigned char *p)
{
    return (uint32_t)p[0] | (uint32_t)p[1]<<8 | (uint32_t)p[2]<<16 | (uint32_t)p[3]<<24;
}
const ME_Session *ME_CurrentSession(void) { return &session; }
int ME_RustProbeEnabled(void) { return session.profile == ME_PROFILE_RUST_PROBE; }
void ME_ApplySessionOptions(void)
{
    if (comp_soul_value >= 0) default_comp[comp_soul] = comp[comp_soul] = comp_soul_value;
}
static const char *String(yyjson_val *v, const char *field)
{
    if (!yyjson_is_str(v) || strlen(yyjson_get_str(v)) != yyjson_get_len(v))
        I_Error("GAMECONF %s must be a string without embedded NUL", field);
    return yyjson_get_str(v);
}
static void CheckKeys(yyjson_val *object, const char *const *keys, size_t count)
{
    if (!yyjson_is_obj(object)) I_Error("GAMECONF object expected");
    uint64_t seen = 0;
    yyjson_obj_iter iter = yyjson_obj_iter_with(object);
    yyjson_val *key;
    while ((key = yyjson_obj_iter_next(&iter))) {
        const char *s = String(key, "key");
        size_t i;
        for (i = 0; i < count && strcmp(keys[i], s); i++);
        if (i == count) I_Error("Unsupported GAMECONF key: %s", s);
        if (seen & (UINT64_C(1)<<i)) I_Error("Duplicate GAMECONF key: %s", s);
        seen |= UINT64_C(1)<<i;
    }
}
static void ParseOptions(const char *text)
{
    char *copy = strdup(text), *save = NULL;
    if (!copy) I_Error("Cannot allocate GAMECONF options");
    for (char *line = strtok_r(copy, "\r\n", &save); line; line = strtok_r(NULL, "\r\n", &save)) {
        char key[64]; int offset = 0;
        if (sscanf(line, " %63s %n", key, &offset) != 1 || !offset || strcmp(key,"comp_soul"))
            I_Error("Unsupported GAMECONF option: %s", line);
        char *end; errno = 0;
        long value = strtol(line+offset,&end,10);
        int has_value = end != line+offset;
        while (isspace((unsigned char)*end)) end++;
        if (!has_value || errno || *end || (value != 0 && value != 1))
            I_Error("Invalid GAMECONF option value: %s", line);
        comp_soul_value = (int)value;
        session.option_count++;
    }
    free(copy);
}
static void ParseGameconf(const void *data, size_t size)
{
    yyjson_doc *doc = yyjson_read(data, size, 0);
    if (!doc) I_Error("Malformed GAMECONF JSON");
    yyjson_val *root = yyjson_doc_get_root(doc);
    static const char *root_keys[] = {"type", "version", "metadata", "data"};
    static const char *data_keys[] = {"title", "author", "description", "version", "iwad",
        "pwadfiles", "pwads", "dehfiles", "executable", "mode", "options",
        "playertranslations", "wadtranslation"};
    CheckKeys(root, root_keys, sizeof(root_keys)/sizeof(*root_keys));
    if (strcmp(String(yyjson_obj_get(root,"type"),"type"),"gameconf") ||
        strcmp(String(yyjson_obj_get(root,"version"),"version"),"1.0.0"))
        I_Error("Unsupported GAMECONF type/version");
    yyjson_val *body = yyjson_obj_get(root,"data");
    CheckKeys(body, data_keys, sizeof(data_keys)/sizeof(*data_keys));
    for (size_t i = 0; i < sizeof(data_keys)/sizeof(*data_keys); i++) {
        const char *key = data_keys[i];
        yyjson_val *v = yyjson_obj_get(body,key);
        if (!v || yyjson_is_null(v)) continue; // null preserves prior values.
        if (!strcmp(key,"pwads") || !strcmp(key,"pwadfiles") || !strcmp(key,"dehfiles")) {
            if (!yyjson_is_arr(v) || yyjson_arr_size(v))
                I_Error("GAMECONF dependency expansion is not implemented: %s", key);
            continue;
        }
        if (!strcmp(key,"playertranslations") || !strcmp(key,"wadtranslation"))
            I_Error("GAMECONF translations are not implemented: %s", key);
        const char *value = String(v,key);
        if (!strcmp(key,"iwad")) {
            if (strchr(value,'/') || strchr(value,'\\') || strchr(value,':') ||
                !value[0] || !strcmp(value,".") || !strcmp(value,".."))
                I_Error("GAMECONF IWAD must be a filename without a path");
            if (strcasecmp(value,base_name))
                I_Error("GAMECONF requires IWAD %s; explicitly supply it as the base", value);
        } else if (!strcmp(key,"executable")) {
            size_t f;
            for (f = 0; f < sizeof(features)/sizeof(*features) && strcmp(features[f],value); f++);
            if (f == sizeof(features)/sizeof(*features)) I_Error("Unknown GAMECONF executable: %s", value);
            if (f > session.declared_feature) session.declared_feature = (uint32_t)f;
        } else if (!strcmp(key,"mode")) {
            if (strcmp(value,"registered") && strcmp(value,"retail") && strcmp(value,"commercial"))
                I_Error("Unknown GAMECONF mode: %s", value);
            // Explicit Doom II base already supplies the highest mode, commercial.
        } else if (!strcmp(key,"options")) ParseOptions(value);
        else if (!strcmp(key,"title")) snprintf(session.title,sizeof(session.title),"%s",value);
        else if (!strcmp(key,"version")) snprintf(session.version,sizeof(session.version),"%s",value);
    }
    yyjson_doc_free(doc);
}
typedef struct { unsigned char *data; size_t size; uint32_t count, directory; } Wad;
static Wad ReadWad(const char *path, int base)
{
    struct stat st;
    if (!path || stat(path,&st) || !S_ISREG(st.st_mode) || st.st_size < 12 || st.st_size > 1024LL*1024*1024)
        I_Error("Missing or invalid WAD file");
    Wad w = {.size = (size_t)st.st_size};
    w.data = malloc(w.size);
    FILE *f = fopen(path,"rb");
    if (!w.data || !f) I_Error("Cannot read WAD: %s", path);
    size_t got = fread(w.data,1,w.size,f); fclose(f);
    if (got != w.size || (memcmp(w.data,"IWAD",4) && memcmp(w.data,"PWAD",4)))
        I_Error("Invalid WAD header: %s", path);
    if (base && memcmp(w.data,"IWAD",4)) I_Error("Selected base is not an IWAD");
    w.count = LE32(w.data+4); w.directory = LE32(w.data+8);
    if (!w.count || w.directory > w.size || w.count > (w.size-w.directory)/16)
        I_Error("Invalid WAD directory: %s", path);
    int map1 = 0, map32 = 0;
    for (uint32_t i = 0; i < w.count; i++) {
        const unsigned char *e = w.data+w.directory+16*i;
        uint32_t offset = LE32(e), length = LE32(e+4);
        if (offset > w.size || length > w.size-offset) I_Error("Invalid WAD lump bounds: %s", path);
        if (!memcmp(e+8,"MAP01\0\0\0",8)) map1 = 1;
        if (!memcmp(e+8,"MAP32\0\0\0",8)) map32 = 1;
        if (!memcmp(e+8,"ID24CONF",8)) I_Error("ID24CONF is not implemented");
    }
    if (base && (!map1 || !map32)) I_Error("Selected base must be a Doom II-format IWAD");
    return w;
}
static void ParseWadConfig(Wad *w)
{
    const unsigned char *found = NULL;
    for (uint32_t i = 0; i < w->count; i++) {
        const unsigned char *e = w->data+w->directory+16*i;
        if (!memcmp(e+8,"GAMECONF",8)) found = e;
    }
    if (found) ParseGameconf(w->data+LE32(found), LE32(found+4));
}
void ME_PlanSession(const ME_Config *config)
{
    if (config->base_wad_index >= config->wad_count || config->profile > ME_PROFILE_RUST_PROBE)
        I_Error("Invalid base WAD index or worker profile");
    memset(&session,0,sizeof(session));
    session.profile = config->profile; session.base_wad_index = config->base_wad_index;
    session.wad_count = config->wad_count;
    const char *base = config->wad_paths[config->base_wad_index];
    if (!base) I_Error("Missing base WAD path");
    base_name = strrchr(base,'/'); base_name = base_name ? base_name+1 : base;
    Wad wads[32];
    unsigned char hashes[32][CC_SHA256_DIGEST_LENGTH];
    struct stat identities[32];
    for (uint32_t i = 0; i < config->wad_count; i++) {
        wads[i] = ReadWad(config->wad_paths[i],i == config->base_wad_index);
        if (stat(config->wad_paths[i],&identities[i])) I_Error("WAD disappeared during planning");
        for (uint32_t j = 0; j < i; j++)
            if (identities[i].st_dev == identities[j].st_dev && identities[i].st_ino == identities[j].st_ino)
                I_Error("Duplicate WAD in session order");
        CC_SHA256(wads[i].data,(CC_LONG)wads[i].size,hashes[i]);
    }
    // GAMECONF resolves base first, regardless of its resource-loading position.
    ParseWadConfig(&wads[config->base_wad_index]);
    for (uint32_t i = 0; i < config->wad_count; i++)
        if (i != config->base_wad_index) ParseWadConfig(&wads[i]);
    if (session.declared_feature == 8 && !ME_RustProbeEnabled())
        I_Error("GAMECONF/ID24 requires explicit Rust probe profile; full ID24 is not supported");
    unsigned char material[16 + sizeof(hashes)] = {'M','E','S','E','S','S','2',0};
    material[8] = config->base_wad_index; material[9] = config->profile; material[10] = config->wad_count;
    memcpy(material+16, hashes, config->wad_count*CC_SHA256_DIGEST_LENGTH);
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(material,(CC_LONG)(16+config->wad_count*CC_SHA256_DIGEST_LENGTH),digest);
    for (unsigned i = 0; i < sizeof(digest); i++) snprintf(session.content_sha256+2*i,3,"%02x",digest[i]);
    for (uint32_t i = 0; i < config->wad_count; i++) free(wads[i].data);
}
