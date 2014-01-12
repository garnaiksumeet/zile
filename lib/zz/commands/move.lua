-- Basic movement commands.
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


Defun ("beginning_of_line",
[[
Move point to beginning of current line.
]],
  true,
  beginning_of_line
)


Defun ("end_of_line",
[[
Move point to end of current line.
]],
  true,
  end_of_line
)


Defun ("backward_char",
[[
Move point left N characters (right if N is negative).
On attempt to pass beginning or end of buffer, stop and signal error.
]],
  true,
  function (n)
    local ok = move_char (-(n or 1))
    if not ok then
      minibuf_error ('Beginning of buffer')
    end
    return ok
  end
)


Defun ("forward_char",
[[
Move point right N characters (left if N is negative).
On reaching end of buffer, stop and signal error.
]],
  true,
  function (n)
    local ok = move_char (n or 1)
    if not ok then
      minibuf_error ('End of buffer')
    end
    return ok
  end
)


Defun ("goto_char",
[[
Set point to @i{position}, a number.
Beginning of buffer is position 1.
]],
  true,
  function (n)
    if not n then
      n = minibuf_read_number ('Goto char: ')
    end

    return type (n) == 'number' and goto_offset (math.min (get_buffer_size (cur_bp) + 1, math.max (n, 1)))
  end
)


Defun ("goto_line",
[[
Goto @i{line}, counting from line 1 at beginning of buffer.
]],
  true,
  function (n)
    n = n or current_prefix_arg
    if not n and command.is_interactive () then
      n = minibuf_read_number ('Goto line: ')
    end

    if type (n) == 'number' then
      move_line ((math.max (n, 1) - 1) - offset_to_line (cur_bp, get_buffer_pt (cur_bp)))
      beginning_of_line ()
    else
      return false
    end
  end
)


Defun ("previous_line",
[[
Move cursor vertically up one line.
If there is no character in the target line exactly over the current column,
the cursor is positioned after the character in that line which spans this
column, or at the end of the line if it is not long enough.
]],
  true,
  function (n)
    return move_line (-(n or current_prefix_arg or 1))
  end
)


Defun ("next_line",
[[
Move cursor vertically down one line.
If there is no character in the target line exactly under the current column,
the cursor is positioned after the character in that line which spans this
column, or at the end of the line if it is not long enough.
]],
  true,
  function (n)
    return move_line (n or current_prefix_arg or 1)
  end
)


Defun ("beginning_of_buffer",
[[
Move point to the beginning of the buffer; leave mark at previous position.
]],
  true,
  function ()
    goto_offset (1)
  end
)


Defun ("end_of_buffer",
[[
Move point to the end of the buffer; leave mark at previous position.
]],
  true,
  function ()
    goto_offset (get_buffer_size (cur_bp) + 1)
  end
)


Defun ("scroll_down",
[[
Scroll text of current window downward near full screen.
]],
  true,
  function (n)
    return execute_with_uniarg (false, n or 1, scroll_down, scroll_up)
  end
)


Defun ("scroll_up",
[[
Scroll text of current window upward near full screen.
]],
  true,
  function (n)
    return execute_with_uniarg (false, n or 1, scroll_up, scroll_down)
  end
)


Defun ("forward_line",
[[
Move N lines forward (backward if N is negative).
Precisely, if point is on line I, move to the start of line I + N.
]],
  true,
  function (n)
    n = n or current_prefix_arg or 1
    if n ~= 0 then
      beginning_of_line ()
      return move_line (n)
    end
    return false
  end
)


local function move_paragraph (uniarg, forward, backward, line_extremum)
  if uniarg < 0 then
    uniarg = -uniarg
    forward = backward
  end

  for i = uniarg, 1, -1 do
    repeat until not is_empty_line () or not forward ()
    repeat until is_empty_line () or not forward ()
  end

  if is_empty_line () then
    beginning_of_line ()
  else
    line_extremum ()
  end
  return true
end


Defun ("backward_paragraph",
[[
Move backward to start of paragraph.  With argument N, do it N times.
]],
  true,
  function (n)
    return move_paragraph (n or 1, previous_line, next_line, beginning_of_line)
  end
)


Defun ("forward_paragraph",
[[
Move forward to end of paragraph.  With argument N, do it N times.
]],
  true,
  function (n)
    return move_paragraph (n or 1, next_line, previous_line, end_of_line)
  end
)


Defun ("forward_sexp",
[[
Move forward across one balanced expression (sexp).
With argument, do it that many times.  Negative arg -N means
move backward across N balanced expressions.
]],
  true,
  function (n)
    return move_with_uniarg (n or 1, move_sexp)
  end
)


Defun ("backward_sexp",
[[
Move backward across one balanced expression (sexp).
With argument, do it that many times.  Negative arg -N means
move forward across N balanced expressions.
]],
  true,
  function (n)
    return move_with_uniarg (-(n or 1), move_sexp)
  end
)


Defun ("back_to_indentation",
[[
Move point to the first non-whitespace character on this line.
]],
  true,
  function ()
    goto_offset (get_buffer_line_o (cur_bp))
    while not eolp () and following_char ():match ('%s') do
      move_char (1)
    end
  end
)


Defun ("forward_word",
[[
Move point forward one word (backward if the argument is negative).
With argument, do this that many times.
]],
  true,
  function (n)
    return move_with_uniarg (n or 1, move_word)
  end
)


Defun ("backward_word",
[[
Move backward until encountering the end of a word (forward if the
argument is negative).
With argument, do this that many times.
]],
  true,
  function (n)
    return move_with_uniarg (-(n or 1), move_word)
  end
)
