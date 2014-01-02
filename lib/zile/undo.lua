-- Undo facility functions
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

-- Save a reverse delta for doing undo.
local function undo_save (ty, o, osize, size)
  if cur_bp.noundo then
    return
  end

  local up = {type = ty, next = cur_bp.last_undop, o = o}

  if ty == "replace block" then
    up.size = size
    up.text = get_buffer_region (cur_bp, region_new (o, o + osize))
    up.unchanged = not cur_bp.modified
  end

  cur_bp.last_undop = up
end


function undo_start_sequence ()
  undo_save ("start sequence", get_buffer_pt (cur_bp), 0, 0)
end

function undo_end_sequence ()
  undo_save ("end sequence", 0, 0, 0)
end

function undo_save_block (o, osize, size)
  undo_save ("replace block", o, osize, size)
end

-- Set unchanged flags to false.
function undo_set_unchanged (up)
  while up do
    up.unchanged = false
    up = up.next
  end
end

-- Revert an action.  Return the next undo entry.
function revert_action (up)
  if up.type == "end sequence" then
    undo_start_sequence ()
    up = up.next
    while up.type ~= "start sequence" do
      up = revert_action (up)
    end
    undo_end_sequence ()
  end

  if up.type ~= "end sequence" then
    goto_offset (up.o)
  end
  if up.type == "replace block" then
    replace_estr (up.size, up.text)
    goto_offset (up.o)
  end

  if up.unchanged then
    cur_bp.modified = false
  end

  return up.next
end
