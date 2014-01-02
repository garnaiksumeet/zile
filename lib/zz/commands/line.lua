-- Line-oriented editing commands.
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
-- along with this program.  If not, see <htt://www.gnu.org/licenses/>.

local eval = require "zz.eval"
local Defun, zz = eval.Defun, eval.sandbox


Defun ("indent_for_tab_command",
  {},
[[
Indent line or insert a tab.
Depending on `tab_always_indent', either insert a tab or indent.
If initial point was within line's indentation, position after
the indentation.  Else stay at same point in text.
]],
  true,
  function ()
    if eval.get_variable_bool ('tab_always_indent') then
      return insert_tab ()
    elseif (get_goalc () < previous_line_indent ()) then
      return zz.indent_relative ()
    end
  end
)


Defun ("indent_relative",
  {},
[[
Space out to under next indent point in previous nonblank line.
An indent point is a non-whitespace character following whitespace.
The following line shows the indentation points in this line.
    ^         ^    ^     ^   ^           ^      ^  ^    ^
If the previous nonblank line has no indent points beyond the
column point starts at, `tab_to_tab_stop' is done instead, unless
this command is invoked with a numeric argument, in which case it
does nothing.
]],
  true,
  function ()
    local target_goalc = 0
    local cur_goalc = get_goalc ()
    local t = tab_width (cur_bp)
    local ok = false

    if warn_if_readonly_buffer () then
      return false
    end

    deactivate_mark ()

    -- If we're on the first line, set target to 0.
    if get_buffer_line_o (cur_bp) == 0 then
      target_goalc = 0
    else
      -- Find goalc in previous non-blank line.
      local m = point_marker ()

      previous_nonblank_goalc ()

      -- Now find the next blank char.
      if preceding_char () ~= '\t' or get_goalc () <= cur_goalc then
        while not eolp () and not following_char ():match ('%s') do
          move_char (1)
        end
      end

      -- Find next non-blank char.
      while not eolp () and following_char ():match ('%s') do
        move_char (1)
      end

      -- Target column.
      if not eolp () then
        target_goalc = get_goalc ()
      end
      goto_offset (m.o)
      unchain_marker (m)
    end

    -- Insert indentation.
    undo_start_sequence ()
    if target_goalc > 0 then
      -- If not at EOL on target line, insert spaces & tabs up to
      -- target_goalc; if already at EOL on target line, insert a tab.
      cur_goalc = get_goalc ()
      if cur_goalc < target_goalc then
        repeat
          if cur_goalc % t == 0 and cur_goalc + t <= target_goalc then
            ok = insert_tab ()
          else
            ok = insert_char (' ')
          end
          cur_goalc = get_goalc ()
        until not ok or cur_goalc >= target_goalc
      else
        ok = insert_tab ()
      end
    else
      ok = insert_tab ()
    end
    undo_end_sequence ()

    return ok
  end
)


Defun ("newline_and_indent",
  {},
[[
Insert a newline, then indent.
Indentation is done using the `indent_for_tab_command' function.
]],
  true,
  function ()
    local ok = false

    if warn_if_readonly_buffer () then
      return false
    end

    deactivate_mark ()

    undo_start_sequence ()
    if insert_newline () then
      local m = point_marker ()
      local pos

      -- Check where last non-blank goalc is.
      previous_nonblank_goalc ()
      pos = get_goalc ()
      local indent = pos > 0 or (not eolp () and following_char ():match ('%s'))
      goto_offset (m.o)
      unchain_marker (m)
      -- Only indent if we're in column > 0 or we're in column 0 and
      -- there is a space character there in the last non-blank line.
      if indent then
        zz.indent_for_tab_command ()
      end
      ok = true
    end
    undo_end_sequence ()

    return ok
  end
)


Defun ("delete_char",
  {"number"},
[[
Delete the following @i{n} characters (previous if @i{n} is negative).
]],
  true,
  function (n)
    return execute_with_uniarg (true, n, delete_char, backward_delete_char)
  end
)


Defun ("backward_delete_char",
  {"number"},
[[
Delete the previous @i{n} characters (following if @i{n} is negative).
]],
  true,
  function (n)
    return execute_with_uniarg (true, n, backward_delete_char, delete_char)
  end
)


Defun ("delete_horizontal_space",
  {},
[[
Delete all spaces and tabs around point.
]],
  true,
  delete_horizontal_space
)


Defun ("just_one_space",
  {},
[[
Delete all spaces and tabs around point, leaving one space.
]],
  true,
  function ()
    undo_start_sequence ()
    delete_horizontal_space ()
    insert_char (' ')
    undo_end_sequence ()
  end
)


Defun ("tab_to_tab_stop",
  {"number"},
[[
Insert a tabulation at the current point position into the current
buffer.
]],
  true,
  function (n)
    return execute_with_uniarg (true, n, insert_tab)
  end
)


local function newline ()
  if cur_bp.autofill and
    get_goalc () > eval.get_variable_number ('fill_column')
  then
    fill_break_line ()
  end
  return insert_newline ()
end


Defun ("newline",
  {"number"},
[[
Insert a newline at the current point position into
the current buffer.
]],
  true,
  function (n)
    return execute_with_uniarg (true, n, newline)
  end
)


Defun ("open_line",
  {"number"},
[[
Insert a newline and leave point before it.
]],
  true,
  function (n)
    return execute_with_uniarg (true, n, intercalate_newline)
  end
)


Defun ("insert",
  {"string"},
[[
Insert the argument at point.
]],
  false,
  function (arg)
    insert_string (arg)
  end
)
