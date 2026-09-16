/*
 * Wine loads its ALSA MIDI driver in the same process as the Windows
 * application.  This small preload library changes only the names
 * used while Wine builds MIDI capability records; it does not alter MIDI
 * messages or the Yamaha executable.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <string.h>

typedef struct snd_seq_client_info snd_seq_client_info_t;
typedef struct snd_seq_port_info snd_seq_port_info_t;

static const char *(*real_client_name)(const snd_seq_client_info_t *);
static const char *(*real_port_name)(const snd_seq_port_info_t *);

static void resolve_symbols(void)
{
    static void *alsa;

    if (!alsa)
        alsa = dlopen("libasound.so.2", RTLD_NOW | RTLD_LOCAL);
    if (!real_client_name && alsa)
        real_client_name = dlsym(alsa, "snd_seq_client_info_get_name");
    if (!real_port_name && alsa)
        real_port_name = dlsym(alsa, "snd_seq_port_info_get_name");
}

const char *snd_seq_client_info_get_name(const snd_seq_client_info_t *info)
{
    static const char long_name[] =
        "AG06/AG03 MIDI compatibility endpoint with a deliberately long client label";
    const char *name;

    resolve_symbols();
    name = real_client_name ? real_client_name(info) : "";
    if (!strcmp(name, "AG06/AG03"))
        return long_name;
    return name;
}

const char *snd_seq_port_info_get_name(const snd_seq_port_info_t *info)
{
    const char *name;

    resolve_symbols();
    name = real_port_name ? real_port_name(info) : "";
    if (!strcmp(name, "AG06/AG03 MIDI 1"))
        return "AG06/AG03";
    return name;
}
