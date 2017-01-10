/*
 *  Dkword.h
 *
 *  $Id$
 *
 *  This file is part of the OpenLink Software Virtuoso Open-Source (VOS)
 *  project.
 *
 *  Copyright (C) 1998-2017 OpenLink Software
 *
 *  This project is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the
 *  Free Software Foundation; only version 2 of the License, dated June 1991.
 *
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
 *  General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  51 Franklin St, Fifth Floor, Boston, MA 02110-1301 USA
 *
 */

#ifndef _DKWORD_H
#define _DKWORD_H

#define LONG_SET_NA(place, l) \
  (((unsigned char *) (place))[0] = (unsigned char) ((l) >> 24), \
   ((unsigned char *) (place))[1] = (unsigned char) ((l) >> 16), \
   ((unsigned char *) (place))[2] = (unsigned char) ((l) >> 8), \
   ((unsigned char *) (place))[3] = (unsigned char) ((l) ))

#define LONG_REF_NA(p) \
  ((((int32) (((unsigned const char *) (p))[0])) << 24) | \
   (((int32) (((unsigned const char *) (p))[1])) << 16) | \
   (((int32) (((unsigned const char *) (p))[2])) << 8) | \
   (((int32) (((unsigned const char *) (p))[3]))) )


#define SHORT_SET_NA(place, l) \
  (((unsigned char *) (place))[0] = (unsigned char) ((l) >> 8), \
   ((unsigned char *) (place))[1] = (unsigned char) ((l) ))

#define SHORT_REF_NA(p) \
  ((((short) (((unsigned const char *) (p))[0])) << 8)  | \
   (((short) (((unsigned const char *) (p))[1]))))


#define LONG_SET_BE(place, l) \
  (((unsigned char *) (place))[3] = (unsigned char) ((l) >> 24), \
   ((unsigned char *) (place))[2] = (unsigned char) ((l) >> 16), \
   ((unsigned char *) (place))[1] = (unsigned char) ((l) >> 8), \
   ((unsigned char *) (place))[0] = (unsigned char) ((l) ))

#define LONG_REF_BE(p) \
  ((((int32) (((unsigned char *) (p))[3])) << 24) | \
   (((int32) (((unsigned char *) (p))[2])) << 16) | \
   (((int32) (((unsigned char *) (p))[1])) << 8) | \
   (((int32) (((unsigned char *) (p))[0]))) )


#define SHORT_SET_BE(place, l) \
  (((unsigned char *) (place))[1] = (unsigned char) ((l) >> 8), \
   ((unsigned char *) (place))[0] = (unsigned char) ((l) ))

#define SHORT_REF_BE(p) \
  ((((short) (((unsigned char *) (p))[1])) << 8)  | \
   (((short) (((unsigned char *) (p))[0]))))


#define INT64_REF_NA(p) \
  (((int64)LONG_REF_NA (p)) << 32 | ((uint32)LONG_REF_NA (((caddr_t)p) + 4)))

#define INT64_SET_NA(p, v) \
  {LONG_SET_NA (p,  (v >> 32));				\
    LONG_SET_NA (((caddr_t)p) + 4, 0xffffffff & v); }

#endif
