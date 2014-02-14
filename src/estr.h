/* Dynamically allocated encoded strings

   Copyright (c) 2011-2014 Free Software Foundation, Inc.

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

/* String with encoding */
typedef struct estr *estr;
typedef struct estr const *const_estr;

extern estr estr_empty;

extern const char *coding_eol_lf;
extern const char *coding_eol_crlf;
extern const char *coding_eol_cr;

void estr_init (void);
_GL_ATTRIBUTE_PURE astr estr_get_as (const_estr es);
_GL_ATTRIBUTE_PURE const char *estr_get_eol (const_estr es);

estr estr_new (const_astr as, const char *eol);
const_estr const_estr_new (const_astr as, const char *eol);

/* Make estr from astr, determining EOL type from astr's contents. */
estr estr_new_astr (const_astr as);

_GL_ATTRIBUTE_PURE size_t estr_prev_line (const_estr es, size_t o);
_GL_ATTRIBUTE_PURE size_t estr_next_line (const_estr es, size_t o);
_GL_ATTRIBUTE_PURE size_t estr_start_of_line (const_estr es, size_t o);
_GL_ATTRIBUTE_PURE size_t estr_end_of_line (const_estr es, size_t o);
_GL_ATTRIBUTE_PURE size_t estr_line_len (const_estr es, size_t o);
_GL_ATTRIBUTE_PURE size_t estr_lines (const_estr es);
estr estr_replace_estr (estr es, size_t pos, const_estr src);
estr estr_cat (estr es, const_estr src);

#define estr_len(es, eol_type) (astr_len (estr_get_as (es)) +  estr_lines (es) * (strlen (eol_type) - strlen (estr_get_eol (es))))

/* Read file contents into an estr.
 * The `as' member is NULL if the file doesn't exist, or other error. */
estr estr_readf (const char *filename);
