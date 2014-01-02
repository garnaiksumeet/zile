-- Marker facility commands.
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


Defun ("exchange_point_and_mark",
  {},
[[
Put the mark where point is now, and point where the mark is now.
]],
  true,
  function ()
    if not cur_bp.mark then
      return minibuf_error ('No mark set in this buffer')
    end

    local tmp = get_buffer_pt (cur_bp)
    goto_offset (cur_bp.mark.o)
    cur_bp.mark.o = tmp
    activate_mark ()
    thisflag.need_resync = true
  end
)


Defun ("set_mark",
  {},
[[
Set this buffer's mark to point.
]],
  false,
  function ()
    set_mark ()
    activate_mark ()
  end
)


Defun ("set_mark_command",
  {},
[[
Set the mark where point is.
]],
  true,
  function ()
    zz.set_mark ()
    minibuf_write ('Mark set')
  end
)


local function mark (uniarg, func)
  zz.set_mark ()
  local ret = func and zz[func] (uniarg)
  if ret then
    zz.exchange_point_and_mark ()
  end
  return ret
end


Defun ("mark_word",
  {"number"},
[[
Set mark argument words away from point.
]],
  true,
  function (n)
    return mark (n, 'forward_word')
  end
)


Defun ("mark_sexp",
  {"number"},
[[
Set mark @i{arg} sexps from point.
The place mark goes is the same place @kbd{C-M-f} would
move to with the same argument.
]],
  true,
  function (n)
    return mark (n, 'forward_sexp')
  end
)


Defun ("mark_paragraph",
  {},
[[
Put point at beginning of this paragraph, mark at end.
The paragraph marked is the one that contains point or follows point.
]],
  true,
  function ()
    if command.was_labelled ':mark_paragraph' then
      zz.exchange_point_and_mark ()
      zz.forward_paragraph ()
      zz.exchange_point_and_mark ()
    else
      zz.forward_paragraph ()
      zz.set_mark ()
      zz.backward_paragraph ()
    end

    command.attach_label ':mark_paragraph'
  end
)


Defun ("mark_whole_buffer",
  {},
[[
Put point at beginning and mark at end of buffer.
]],
  true,
  function ()
    goto_offset (get_buffer_size (cur_bp) + 1)
    zz.set_mark_command ()
    goto_offset (1)
  end
)
