/* Lisp parser

   Copyright (c) 2001-2011 Free Software Foundation, Inc.

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

#include "main.h"
#include "extern.h"

void
init_lisp (void)
{
  leNIL = leNew ("nil");
  leT = leNew ("t");
}


typedef enum
{
  t_eof,
  t_closeparen,
  t_openparen,
  t_newline,
  t_quote,
  t_word,
} tokenname;

static int
read_char (astr as, size_t * pos)
{
  if ((size_t) *pos < astr_len (as))
    return astr_get (as, (*pos)++);
  return EOF;
}

static astr
read_token (tokenname *tokenid, astr as, size_t * pos)
{
  int c;
  int doublequotes = 0;
  astr tok = astr_new ();

  *tokenid = t_eof;

  /* Chew space to next token */
  do
    {
      c = read_char (as, pos);

      /* Munch comments */
      if (c == ';')
        do
          c = read_char (as, pos);
        while (c != EOF && c != '\n');
    }
  while (c != EOF && (c == ' ' || c == '\t'));

  /* Snag token */
  if (c == '(')
    {
      *tokenid = t_openparen;
      return tok;
    }
  else if (c == ')')
    {
      *tokenid = t_closeparen;
      return tok;
    }
  else if (c == '\'')
    {
      *tokenid = t_quote;
      return tok;
    }
  else if (c == '\n')
    {
      *tokenid = t_newline;
      return tok;
    }
  else if (c == EOF)
    {
      *tokenid = t_eof;
      return tok;
    }

  /* It looks like a string. Snag to the next whitespace. */
  if (c == '\"')
    {
      doublequotes = 1;
      c = read_char (as, pos);
    }

  for (;;)
    {
      astr_cat_char (tok, (char) c);

      if (!doublequotes)
        {
          if (c == ')' || c == '(' || c == ';' || c == ' ' || c == '\n'
              || c == '\r' || c == EOF)
            {
              (*pos)--;
              astr_truncate (tok, astr_len (tok) - 1);
              *tokenid = t_word;
              return tok;
            }
        }
      else
        {
          switch (c)
            {
            case '\n':
            case '\r':
            case EOF:
              (*pos)--;
              /* Fall through */

            case '\"':
              astr_truncate (tok, astr_len (tok) -1);
              *tokenid = t_word;
              return tok;
              break;

            default:
              break;
            }
        }

      c = read_char (as, pos);
    }

  return tok;
}

static le *
lisp_read (le * list, astr as, size_t * pos)
{
  int quoted = false;

  for (;;)
    {
      tokenname tokenid;
      astr tok = read_token (&tokenid, as, pos);

      switch (tokenid)
        {
        case t_quote:
          quoted = true;
          break;

        case t_openparen:
          list = leAddBranchElement (list, lisp_read (NULL, as, pos), quoted);
          quoted = false;
          break;

        case t_newline:
          quoted = false;
          break;

        case t_word:
          list = leAddDataElement (list, astr_cstr (tok), quoted);
          quoted = false;
          break;

        case t_closeparen:
        case t_eof:
          return list;

        default:
          break;
        }
    }
}

void
lisp_loadstring (astr as)
{
  size_t pos = 0;
  leEval (lisp_read (NULL, as, &pos));
}

bool
lisp_loadfile (const char *file)
{
  astr bs = astr_readf (file);
  if (bs == NULL)
    return false;
  lisp_loadstring (bs);
  return true;
}

DEFUN ("load", load)
/*+
Execute a file of Lisp code named FILE.
+*/
{
  if (arglist && countNodes (arglist) >= 2)
    ok = bool_to_lisp (lisp_loadfile (arglist->next->data));
  else
    ok = leNIL;
}
END_DEFUN
