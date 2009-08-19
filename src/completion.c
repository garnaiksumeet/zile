/* Completion facility functions

   Copyright (c) 1997, 1998, 1999, 2000, 2001, 2002, 2003, 2004, 2008, 2009 Free Software Foundation, Inc.

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

#include "config.h"

#include <sys/stat.h>
#include <assert.h>
#include <dirent.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "dirname.h"
#include "gl_linked_list.h"

#include "main.h"
#include "extern.h"


/*
 * Structure
 */
#define FIELD(cty, lty, field)                  \
  LUA_GETTER (completion, cty, lty, field)      \
  LUA_SETTER (completion, cty, lty, field)

#define FIELD_STR(field)                                 \
  LUA_GETTER (completion, const char *, string, field)   \
  LUA_SETTER (completion, const char *, string, field)

#include "completion.h"
#undef FIELD
#undef FIELD_STR

/*
 * List methods for completions and matches
 */
int
completion_strcmp (const void *p1, const void *p2)
{
  return strcmp ((char *) p1, (char *) p2);
}

static bool
completion_streq (const void *p1, const void *p2)
{
  return strcmp ((char *) p1, (char *) p2) == 0;
}

/*
 * Allocate a new completion structure.
 */
Completion
completion_new (int fileflag)
{
  Completion cp;

  lua_newtable (L);
  cp = luaL_ref (L, LUA_REGISTRYINDEX);
  set_completion_completions (cp, gl_list_create_empty (GL_LINKED_LIST,
                                                        completion_streq, NULL,
                                                        list_free, false));
  set_completion_matches (cp, gl_list_create_empty (GL_LINKED_LIST,
                                                    completion_streq, NULL,
                                                    NULL, false));

  if (fileflag)
    {
      set_completion_path (cp, astr_new ());
      set_completion_flags (cp, CFLAG_FILENAME);
    }

  return cp;
}

/*
 * Dispose an completion structure.
 */
void
free_completion (Completion cp)
{
  gl_list_free (get_completion_completions (cp));
  gl_list_free (get_completion_matches (cp));
  if (get_completion_flags (cp) & CFLAG_FILENAME)
    astr_delete (get_completion_path (cp));
}

/*
 * Scroll completions up.
 */
void
completion_scroll_up (void)
{
  Window *wp, *old_wp = cur_wp;
  Point pt;

  wp = find_window ("*Completions*");
  assert (wp != NULL);
  set_current_window (wp);
  pt = get_buffer_pt (cur_bp);
  if (pt.n >= get_buffer_last_line (cur_bp) - get_window_eheight (cur_wp) || !FUNCALL (scroll_up))
    gotobob ();
  set_current_window (old_wp);

  term_redisplay ();
}

/*
 * Scroll completions down.
 */
void
completion_scroll_down (void)
{
  Window *wp, *old_wp = cur_wp;
  Point pt;

  wp = find_window ("*Completions*");
  assert (wp != NULL);
  set_current_window (wp);
  pt = get_buffer_pt (cur_bp);
  if (pt.n == 0 || !FUNCALL (scroll_down))
    {
      gotoeob ();
      resync_redisplay ();
    }
  set_current_window (old_wp);

  term_redisplay ();
}

/*
 * Calculate the maximum length of the completions.
 */
static size_t
calculate_max_length (gl_list_t l, size_t size)
{
  size_t i, maxlen = 0;

  for (i = 0; i < MIN (size, gl_list_size (l)); i++)
    {
      size_t len = strlen ((char *) gl_list_get_at (l, i));
      maxlen = MAX (len, maxlen);
    }

  return maxlen;
}

/*
 * Print the list of completions in a set of columns.
 */
static void
completion_print (gl_list_t l, size_t size)
{
  size_t i, j, col, max, numcols;

  max = calculate_max_length (l, size) + 5;
  numcols = (get_window_ewidth (cur_wp) - 1) / max;

  bprintf ("Possible completions are:\n");
  for (i = col = 0; i < MIN (size, gl_list_size (l)); i++)
    {
      char *s = (char *) gl_list_get_at (l, i);
      size_t len = strlen (s);
      if (col >= numcols)
        {
          col = 0;
          insert_newline ();
        }
      insert_nstring (s, len);
      for (j = max - len; j > 0; --j)
        insert_char_in_insert_mode (' ');
      ++col;
    }
}

static void
write_completion (va_list ap)
{
  Completion cp = va_arg (ap, Completion);
  size_t num = va_arg (ap, size_t);
  completion_print (get_completion_matches (cp), num);
}

/*
 * Popup the completion window.
 */
void
popup_completion (Completion cp)
{
  set_completion_flags (cp, get_completion_flags (cp) | CFLAG_POPPEDUP);
  if (get_window_next (head_wp) == NULL)
    set_completion_flags (cp, get_completion_flags (cp) | CFLAG_CLOSE);

  write_temp_buffer ("*Completions*", true, write_completion, cp, get_completion_partmatches (cp));

  if (!(get_completion_flags (cp) & CFLAG_CLOSE))
    set_completion_old_bp (cp, cur_bp);

  term_redisplay ();
}

/*
 * Reread directory for completions.
 */
static int
completion_readdir (Completion cp, astr as)
{
  DIR *dir;
  char *s1, *s2;
  const char *pdir, *base;
  struct dirent *d;
  struct stat st;
  astr bs;

  gl_list_free (get_completion_completions (cp));

  set_completion_completions (cp, gl_list_create_empty (GL_LINKED_LIST,
                                                        completion_streq, NULL,
                                                        list_free, false));

  if (!expand_path (as))
    return false;

  bs = astr_new ();

  /* Split up path with dirname and basename, unless it ends in `/',
     in which case it's considered to be entirely dirname */
  s1 = xstrdup (astr_cstr (as));
  s2 = xstrdup (astr_cstr (as));
  if (astr_get (as, astr_len (as) - 1) != '/')
    {
      pdir = dir_name (s1);
      /* Append `/' to pdir */
      astr_cat_cstr (bs, pdir);
      if (astr_get (bs, astr_len (bs) - 1) != '/')
        astr_cat_char (bs, '/');
      free ((char *) pdir);
      pdir = astr_cstr (bs);
      base = base_name (s2);
    }
  else
    {
      pdir = s1;
      base = xstrdup ("");
    }

  astr_cpy_cstr (as, base);
  free ((char *) base);

  dir = opendir (pdir);
  if (dir != NULL)
    {
      astr buf = astr_new ();
      while ((d = readdir (dir)) != NULL)
        {
          astr_cpy_cstr (buf, pdir);
          astr_cat_cstr (buf, d->d_name);
          if (stat (astr_cstr (buf), &st) != -1)
            {
              astr_cpy_cstr (buf, d->d_name);
              if (S_ISDIR (st.st_mode))
                astr_cat_char (buf, '/');
            }
          else
            astr_cpy_cstr (buf, d->d_name);
          gl_sortedlist_add (get_completion_completions (cp), completion_strcmp,
                             xstrdup (astr_cstr (buf)));
        }
      closedir (dir);

      astr_delete (get_completion_path (cp));
      set_completion_path (cp, compact_path (astr_new_cstr (pdir)));
      astr_delete (buf);
    }

  astr_delete (bs);
  free (s1);
  free (s2);

  return dir != NULL;
}

/*
 * Match completions.
 */
int
completion_try (Completion cp, astr search)
{
  size_t i, j, ssize;
  size_t fullmatches = 0;
  char c;

  set_completion_partmatches (cp, 0);
  gl_list_free (get_completion_matches (cp));
  set_completion_matches (cp, gl_list_create_empty (GL_LINKED_LIST, completion_streq, NULL, NULL, false));

  if (get_completion_flags (cp) & CFLAG_FILENAME)
    if (!completion_readdir (cp, search))
      return COMPLETION_NOTMATCHED;

  ssize = astr_len (search);

  for (i = 0; i < gl_list_size (get_completion_completions (cp)); i++)
    {
      char *s = (char *) gl_list_get_at (get_completion_completions (cp), i);
      if (!strncmp (s, astr_cstr (search), ssize))
        {
          set_completion_partmatches (cp, get_completion_partmatches (cp) + 1);
          gl_sortedlist_add (get_completion_matches (cp), completion_strcmp, s);
          if (!strcmp (s, astr_cstr (search)))
            ++fullmatches;
        }
    }

  if (get_completion_partmatches (cp) == 0)
    return COMPLETION_NOTMATCHED;
  else if (get_completion_partmatches (cp) == 1)
    {
      set_completion_match (cp, (char *) gl_list_get_at (get_completion_matches (cp), 0));
      set_completion_matchsize (cp, strlen (get_completion_match (cp)));
      return COMPLETION_MATCHED;
    }

  if (fullmatches == 1 && get_completion_partmatches (cp) > 1)
    {
      set_completion_match (cp, (char *) gl_list_get_at (get_completion_matches (cp), 0));
      set_completion_matchsize (cp, strlen (get_completion_match (cp)));
      return COMPLETION_MATCHEDNONUNIQUE;
    }

  for (j = ssize;; ++j)
    {
      const char *s = (char *) gl_list_get_at (get_completion_matches (cp), 0);

      c = s[j];
      for (i = 1; i < get_completion_partmatches (cp); ++i)
        {
          s = gl_list_get_at (get_completion_matches (cp), i);
          if (s[j] != c)
            {
              set_completion_match (cp, (char *) gl_list_get_at (get_completion_matches (cp), 0));
              set_completion_matchsize (cp, j);
              return COMPLETION_NONUNIQUE;
            }
        }
    }

  abort ();
}

char *
minibuf_read_variable_name (char *fmt, ...)
{
  va_list ap;
  char *ms;
  Completion cp = completion_new (false);

  lua_getglobal (L, "main_vars");
  lua_pushnil (L);
  while (lua_next (L, -2) != 0) {
    char *s = (char *) lua_tostring (L, -2);
    assert (s);
    gl_sortedlist_add (get_completion_completions (cp), completion_strcmp,
                       xstrdup (s));
    lua_pop (L, 1);
  }
  lua_pop (L, 1);

  va_start (ap, fmt);
  ms = minibuf_vread_completion (fmt, "", cp, NULL,
                                 "No variable name given",
                                 minibuf_test_in_completions,
                                 "Undefined variable name `%s'", ap);
  va_end (ap);

  return ms;
}

Completion
make_buffer_completion (void)
{
  Buffer *bp;
  Completion cp = completion_new (false);

  for (bp = head_bp; bp != NULL; bp = get_buffer_next (bp))
    gl_sortedlist_add (get_completion_completions (cp), completion_strcmp,
                       xstrdup (get_buffer_name (bp)));

  return cp;
}
