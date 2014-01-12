-- Search and replace commands.
--
-- Copyright (c) 2010-2014 Free Software Foundation, Inc.
--
-- This file is part of GNU Zile.
--
-- This program is free software; you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 3, or (at your option)
-- any later version.
--
-- This program is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
-- General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.

local eval  = require "zz.eval"
local Defun = eval.Defun


Defun ("search_forward",
[[
Search forward from point for the user specified text.
]],
  true,
  function (pattern)
    return do_search (true, false, pattern)
  end
)


Defun ("search_backward",
[[
Search backward from point for the user specified text.
]],
  true,
  function (pattern)
    return do_search (false, false, pattern)
  end
)


Defun ("search_forward_regexp",
[[
Search forward from point for regular expression REGEXP.
]],
  true,
  function (pattern)
    return do_search (true, true, pattern)
  end
)


Defun ("search_backward_regexp",
[[
Search backward from point for match for regular expression REGEXP.
]],
  true,
  function (pattern)
    return do_search (false, true, pattern)
  end
)


Defun ("isearch_forward",
[[
Do incremental search forward.
With a prefix argument, do an incremental regular expression search instead.
As you type characters, they add to the search string and are found.
Type return to exit, leaving point at location found.
Type @kbd{C-s} to search again forward, @kbd{C-r} to search again backward.
@kbd{C-g} when search is successful aborts and moves point to starting point.
]],
  true,
  function ()
    return isearch (true, lastflag.set_uniarg)
  end
)


Defun ("isearch_backward",
[[
Do incremental search backward.
With a prefix argument, do a regular expression search instead.
As you type characters, they add to the search string and are found.
Type return to exit, leaving point at location found.
Type @kbd{C-r} to search again backward, @kbd{C-s} to search again forward.
@kbd{C-g} when search is successful aborts and moves point to starting point.
]],
  true,
  function ()
    return isearch (false, lastflag.set_uniarg)
  end
)


Defun ("isearch_forward_regexp",
[[
Do incremental search forward for regular expression.
With a prefix argument, do a regular string search instead.
Like ordinary incremental search except that your input
is treated as a regexp.  See @kbd{M-x isearch_forward} for more info.
]],
  true,
  function ()
    return isearch (true, not lastflag.set_uniarg)
  end
)


Defun ("isearch_backward_regexp",
[[
Do incremental search backward for regular expression.
With a prefix argument, do a regular string search instead.
Like ordinary incremental search except that your input
is treated as a regexp.  See @kbd{M-x isearch_backward} for more info.
]],
  true,
  function ()
    return isearch (false, not lastflag.set_uniarg)
  end
)


-- Check the case of a string.
-- Returns 'uppercase' if it is all upper case, 'capitalized' if just
-- the first letter is, and nil otherwise.
local function check_case (s)
  if s:match ('^%u+$') then
    return 'uppercase'
  elseif s:match ('^%u%U*') then
    return 'capitalized'
  end
end


Defun ("query_replace",
[[
Replace occurrences of a string with other text.
As each match is found, the user must type a character saying
what to do with it.
]],
  true,
  function ()
    local find = minibuf_read ('Query replace string: ', '')
    if not find then
      return keyboard_quit ()
    end
    if find == '' then
      return false
    end
    local find_no_upper = no_upper (find, false)

    local repl = minibuf_read (string.format ([[Query replace `%s' with: ]], find), '')
    if not repl then
      keyboard_quit ()
    end

    local noask = false
    local count = 0
    local ok = true
    while search (get_buffer_pt (cur_bp), find, true, false) do
      local c = keycode ' '

      if not noask then
        if thisflag.need_resync then
          window_resync (cur_wp)
        end
        minibuf_write (string.format ([[Query replacing `%s' with `%s' (y, n, !, ., q)? ]], find, repl))
        c = getkey (GETKEY_DEFAULT)
        minibuf_clear ()

        if c == keycode 'q' then -- Quit immediately.
          break
        elseif c == keycode '\\C-g' then
          ok = keyboard_quit ()
          break
        elseif c == keycode '!' then -- Replace all without asking.
          noask = true
        end
      end

      if keyset {' ', 'y', 'Y', '.', '!'}:member (c) then
        -- Perform replacement.
        count = count + 1
        local case_repl = repl
        local r = region_new (get_buffer_pt (cur_bp) - #find, get_buffer_pt (cur_bp))
        if find_no_upper and eval.get_variable ('case_replace') then
          local case_type = check_case (tostring (get_buffer_region (cur_bp, r))) -- FIXME
          if case_type then
            case_repl = recase (repl, case_type)
          end
        end
        local m = point_marker ()
        goto_offset (r.start)
        replace_estr (#find, EStr (case_repl))
        goto_offset (m.o)
        unchain_marker (m)

        if c == keycode '.' then -- Replace and quit.
          break
        end
      elseif not keyset {'n', 'N', '\\RET', '\\DELETE'}:member (c) then
        ungetkey (c)
        ok = false
        break
      end
    end

    if thisflag.need_resync then
      window_resync (cur_wp)
    end

    if ok then
      minibuf_write (string.format ('Replaced %d occurrence%s', count, count ~= 1 and 's' or ''))
    end

    return ok
  end
)
