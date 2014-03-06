-- Buffer-oriented commands.
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

local eval  = require "zz.eval"
local Defun = eval.Defun


Defun ("kill_buffer",
[[
Kill buffer BUFFER.
With a nil argument, kill the current buffer.
]],
  true,
  function (buffer)
    local ok = true

    if not buffer then
      local cp = make_buffer_completion ()
      buffer = minibuf_read (string.format ('Kill buffer (default %s): ', cur_bp.name),
                             '', cp, buffer_name_history)
      if not buffer then
        ok = keyboard_quit ()
      end
    end

    local bp
    if buffer and buffer ~= '' then
      bp = get_buffer (buffer)
      if not bp then
        minibuf_error (string.format ([[Buffer `%s' not found]], buffer))
        ok = false
      end
    else
      bp = cur_bp
    end

    if ok then
      if not check_modified_buffer (bp) then
        ok = false
      else
        kill_buffer (bp)
      end
    end

    return ok
  end
)


Defun ("switch_to_buffer",
[[
Select buffer @i{buffer} in the current window.
]],
  true,
  function (buffer)
    local ok = true
    local bp = buffer_next (cur_bp)

    if not buffer then
      local cp = make_buffer_completion ()
      buffer = minibuf_read (string.format ('Switch to buffer (default %s): ', bp.name),
                             '', cp, buffer_name_history)

      if not buffer then
        ok = keyboard_quit ()
      end
    end

    if ok then
      if buffer and buffer ~= '' then
        bp = get_buffer (buffer)
        if not bp then
          bp = buffer_new ()
          bp.name = buffer
          bp.needname = true
          bp.nosave = true
        end
      end

      switch_to_buffer (bp)
    end

    return ok
  end
)


Defun ("toggle_read_only",
[[
Change whether this buffer is visiting its file read-only.
]],
  true,
  function ()
    cur_bp.readonly = not cur_bp.readonly
  end
)


Defun ("auto_fill_mode",
[[
Toggle Auto Fill mode.
In Auto Fill mode, inserting a space at a column beyond `fill-column'
automatically breaks the line at a previous space.
]],
  true,
  function ()
    cur_bp.autofill = not cur_bp.autofill
  end
)


local function write_buffers_list (old_wp)
  insert_string ('CRM Buffer                Size  Mode             File\n')
  insert_string ('--- ------                ----  ----             ----\n')

  -- Rotate buffer list to get current buffer at head.
  local bufs = table.clone (buffers)
  for i = #buffers, 1, -1 do
    if buffers[i] == old_wp.bp then
      break
    end
    table.insert (bufs, 1, table.remove (bufs))
  end

  -- Print buffers.
  for _, bp in ripairs (bufs) do
    -- Print all buffers whose names don't start with space except
    -- this one (the *Buffer List*).
    if cur_bp ~= bp and bp.name[1] ~= ' ' then
      insert_string (string.format ('%s%s%s %-19s %6u  %-17s',
                                    old_wp.bp == bp and '.' or ' ',
                                    bp.readonly and '%' or ' ',
                                    bp.modified and '*' or ' ',
                                    bp.name, get_buffer_size (bp), 'Fundamental'))
      if bp.filename then
        insert_string (compact_path (bp.filename))
      end
      insert_string "\n"
    end
  end
end


Defun ("list_buffers",
[[
Display a list of names of existing buffers.
The list is displayed in a buffer named `*Buffer List*'.

The C column has a `.' for the buffer from which you came.
The R column has a `%' if the buffer is read-only.
The M column has a `*' if it is modified.
After this come the buffer name, its size in characters,
its major mode, and the visited file name (if any).
]],
  true,
  function ()
    write_temp_buffer ('*Buffer List*', true, write_buffers_list, cur_wp)
  end
)
