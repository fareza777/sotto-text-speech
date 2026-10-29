#ifndef LAME_CONFIG_H
#define LAME_CONFIG_H

#include <stdint.h>
#include <stddef.h>

#define HAVE_ERRNO_H 1
#define HAVE_FCNTL_H 1
#define HAVE_GETTIMEOFDAY 1
#define HAVE_INTTYPES_H 1
#define HAVE_LIMITS_H 1
#define HAVE_MEMORY_H 1
#define HAVE_STDINT_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRINGS_H 1
#define HAVE_STRING_H 1
#define HAVE_SYS_STAT_H 1
#define HAVE_SYS_TIME_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_UNISTD_H 1
#define HAVE_STRCHR 1
#define HAVE_STRDUP 1
#define HAVE_STRSTR 1
#define HAVE_STRTOL 1
#define STDC_HEADERS 1
#define TIME_WITH_SYS_TIME 1
#define LAME_LIBRARY_BUILD 1
#define restrict __restrict

typedef float ieee754_float32_t;
typedef double ieee754_float64_t;

#define VERSION "3.100"
#define PACKAGE "lame"

#endif
