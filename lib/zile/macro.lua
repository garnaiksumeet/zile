-- Macro facility functions
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

cmd_mp = {}
cur_mp = {}

function add_cmd_to_macro ()
  cur_mp = list.concat (cur_mp, cmd_mp)
  cmd_mp = {}
end

function add_key_to_cmd (key)
  table.insert (cmd_mp, key)
end

function remove_key_from_cmd ()
  table.remove (cmd_mp)
end

function cancel_kbd_macro ()
  cmd_mp = {}
  cur_mp = {}
  thisflag.defining_macro = false
end

local function process_keys (keys)
  local cur = term_buf_len ()

  for i = #keys, 1, -1 do
    term_ungetkey (keys[i])
  end

  undo_start_sequence ()
  while term_buf_len () > cur do
    get_and_run_command ()
  end
  undo_end_sequence ()
end

macro_keys = {}

function call_macro ()
  process_keys (macro_keys)
  return true
end
