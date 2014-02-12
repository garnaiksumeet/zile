/* Veneers for libgc functions.

   Copyright (c) 2014 Free Software Foundation, Inc.

   This file is part of GNU Zile.

   GNU Zile is free software; you can redistribute it and/or modify it
   under the terms of the GNU General Public License as published by
   the Free Software Foundation; either version 3, or (at your option)
   any later version.

   GNU Zile is distributed in the hope that it will be useful, but
   WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
   General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with GNU Zile; see the file COPYING.  If not, write to the
   Free Software Foundation, Fifth Floor, 51 Franklin Street, Boston,
   MA 02111-1301, USA.  */

#include <config.h>

#include <stdlib.h>
#include <string.h>


/* This veneer allows libgc to be used via preprocessor trickery to
   override the standard function names without upsetting system
   headers. In particular, this means we cannot use macros with
   arguments, so as libgc has no calloc function, we must implement it
   as a trivial function. */
void *
zile_calloc(size_t n, size_t s)
{
  size_t size = n * s;
  void *p = malloc(size);
  return p ? memset(p, 0, size) : NULL;
}
