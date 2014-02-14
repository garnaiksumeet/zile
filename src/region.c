/* Regions

   Copyright (c) 1997-2014 Free Software Foundation, Inc.

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

#include "main.h"
#include "extern.h"


struct Region
{
#define FIELD(ty, name) ty name;
#include "region.h"
#undef FIELD
};

#define FIELD(ty, field)                         \
  POINTER_GETTER (Region, region, ty, field)     \
  POINTER_SETTER (Region, region, ty, field)

#include "region.h"
#undef FIELD

/*
 * Make a region from two offsets.
 */
Region
region_new (size_t o1, size_t o2)
{
  Region r = XZALLOC (struct Region);
  r->start = MIN (o1, o2);
  r->end = MAX (o1, o2);
  return r;
}

_GL_ATTRIBUTE_PURE size_t
get_region_size (const Region r)
{
  return get_region_end (r) - get_region_start (r);
}

/*
 * Return the region between point and mark.
 */
Region
calculate_the_region (void)
{
  return region_new (get_buffer_pt (cur_bp), get_marker_o (get_buffer_mark (cur_bp)));
}

bool
delete_region (const Region r)
{
  if (warn_if_readonly_buffer ())
    return false;

  Marker *m = point_marker ();
  goto_offset (get_region_start (r));
  replace_estr (get_region_size (r), estr_empty);
  goto_offset (get_marker_o (m));
  unchain_marker (m);
  return true;
}

bool
region_contains (Region r, size_t o)
{
  return o >= get_region_start (r) && o < get_region_end (r);
}
