/*
 *  util - some useful macros and functions
 *
 * Copyright (C) 2008 Liu Yubao <yubao.liu@gmail.com>
 *
 * This library is free software; you can redistribute it and/or
 * modify it under the terms of the GNU Lesser General Public
 * License as published by the Free Software Foundation; either
 * version 2.1 of the License, or (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
 * Lesser General Public License for more details.
 *
 */
#ifndef UTIL_H__
#define UTIL_H__

#include <errno.h>
#include <stddef.h>
#include <stdint.h>
#include <stdlib.h>
#include <unistd.h>

#ifdef __cplusplus
extern "C" {
#endif


#if defined(__GNUC__) && (__GNUC__ > 2)
#define likely(x)	__builtin_expect(!!(x), 1)
#define unlikely(x)	__builtin_expect(!!(x), 0)
#else
#define likely(x)   (x)
#define unlikely(x) (x)
#endif


#define     ERROR_IF(cond, s, ...)  \
    do {                            \
        if (unlikely(cond)) {       \
            fprintf(stderr, "[%s:%d] " s "\n", __FILE__, __LINE__,      \
                    ##__VA_ARGS__); \
            goto L_error;           \
        }                           \
    } while (0)


#define     ERRORP_IF(cond, s, ...) \
    do {                            \
        if (unlikely(cond)) {       \
            fprintf(stderr, "[%s:%d] " s ": %s\n", __FILE__, __LINE__,  \
                    ##__VA_ARGS__, strerror(errno));                    \
            goto L_error;           \
        }                           \
    } while (0)


#define     DEBUG(s, ...)      \
    fprintf(stderr, "[%s:%d] " s "\n", __FILE__, __LINE__, ##__VA_ARGS__)


#define     ALIGN_UP(n, a)      (((n) + (a) - 1) & ~((size_t)(a) - 1))
#define     ALIGN_DOWN(n, a)    ((n) & ~((size_t)(a) - 1))


#define     MAX(a, b)   ((a) > (b) ? (a) : (b))
#define     MIN(a, b)   ((a) > (b) ? (b) : (a))


/*
 * a = b + c, set a to maximum if wrap around.
 */
#define     ADD_TO_MAX_NO_WRAP(a, b, c, m)  \
    do {    \
        if (unlikely((m) - (b) > (c))) (a) = (b) + (c); else (a) = (m);   \
    } while (0)

/*
 * a = b - c, set a to minimum if wrap around.
 */
#define     SUB_TO_MIN_NO_WRAP(a, b, c, m)  \
    do {    \
        if (unlikely((b) - (m) > (c))) (a) = (b) - (c); else (a) = (m);   \
    } while (0)


/*
 * copied from git/git-compat-util.h
 */
static inline ssize_t xread(int fd, void *buf, size_t len)
{
    ssize_t nr;
    while (1) {
        nr = read(fd, buf, len);
        if ((nr < 0) && (errno == EAGAIN || errno == EINTR))
            continue;
        return nr;
    }
}


/*
 * copied from git/git-compat-util.h
 */
static inline ssize_t xwrite(int fd, const void *buf, size_t len)
{
    ssize_t nr;
    while (1) {
        nr = write(fd, buf, len);
        if ((nr < 0) && (errno == EAGAIN || errno == EINTR))
            continue;
        return nr;
    }
}


ssize_t
readn(int fd, void* buf, size_t n);

ssize_t
writen(int fd, const void* buf, size_t n);


typedef struct {
    char        a;
    int64_t     b;
} check_struct_pack_t;

static inline int
get_struct_pack(void)
{
    switch (sizeof(check_struct_pack_t)) {
    case 9:
        return 0;       /* pack(1)                  */
    case 10:
        return 1;       /* pack(2)                  */
    case 12:
        return 2;       /* pack(4)                  */
    case 16:
        return 3;       /* pack(8)                  */
    default:
        abort();        /* should never reach here  */
        return 3;
    }
}


#ifdef __cplusplus
}
#endif


#endif /* UTIL_H__ */

