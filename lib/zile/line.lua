-- Line-oriented editing functions
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
-- along with this program; see the file COPYING.  If not, write to the
-- Free Software Foundation, Fifth Floor, 51 Franklin Street, Boston,
-- MA 02111-1301, USA.


local FileString = require "zile.FileString"

function insert_string (s, eol)
  return insert_estr (FileString (s, eol or coding_eol_lf))
end

function delete_horizontal_space ()
  undo_start_sequence ()

  while not eolp () and following_char ():match ("%s") do
    delete_char ()
  end

  while not bolp () and preceding_char ():match ("%s") do
    backward_delete_char ()
  end

  undo_end_sequence ()
end

-- If point is greater than fill-column, then split the line at the
-- right-most space character at or before fill-column, if there is
-- one, or at the left-most at or after fill-column, if not. If the
-- line contains no spaces, no break is made.
--
-- Return flag indicating whether break was made.
function fill_break_line ()
  local i, old_col
  local break_col = 0
  local fillcol = eval.get_variable ("fill_column")
  local break_made = false

  -- Only break if we're beyond fill-column.
  if get_goalc () > fillcol then
    -- Save point.
    local m = point_marker ()

    -- Move cursor back to fill column
    old_col = get_buffer_pt (cur_bp) - get_buffer_line_o (cur_bp)
    while get_goalc () > fillcol + 1 do
      move_char (-1)
    end

    -- Find break point moving left from fill-column.
    for i = get_buffer_pt (cur_bp) - get_buffer_line_o (cur_bp), 1, -1 do
      if get_buffer_char (cur_bp, get_buffer_line_o (cur_bp) + i - 1):match ("%s") then
        break_col = i
        break
      end
    end

    -- If no break point moving left from fill-column, find first
    -- possible moving right.
    if break_col == 0 then
      for i = get_buffer_pt (cur_bp) + 1, buffer_end_of_line (cur_bp, get_buffer_line_o (cur_bp)) do
        if get_buffer_char (cur_bp, i - 1):match ("%s") then
          break_col = i - get_buffer_line_o (cur_bp)
          break
        end
      end
    end

    if break_col >= 1 then -- Break line.
      goto_offset (get_buffer_line_o (cur_bp) + break_col)
      delete_horizontal_space ()
      insert_string "\n"
      goto_offset (m.o)
      break_made = true
    else -- Undo fiddling with point.
      goto_offset (get_buffer_line_o (cur_bp) + old_col)
    end

    unchain_marker (m)
  end

  return break_made
end

-- Insert a newline at the current position without moving the cursor.
function intercalate_newline ()
  return insert_string "\n" and move_char (-1)
end

local function insert_expanded_tab ()
  local t = tab_width (cur_bp)
  insert_string (string.rep (' ', t - get_goalc () % t))
end

function insert_tab ()
  if warn_if_readonly_buffer () then
    return false
  end

  if eval.get_variable ("indent_tabs_mode") then
    insert_char ('\t')
  else
    insert_expanded_tab ()
  end

  return true
end

function backward_delete_char ()
  deactivate_mark ()

  if not move_char (-1) then
    minibuf_error ("Beginning of buffer")
    return false
  end

  delete_char ()
  return true
end

-- Indentation command
-- Go to cur_goalc () in the previous non-blank line.
function previous_nonblank_goalc ()
  local cur_goalc = get_goalc ()

  -- Find previous non-blank line.
  while move_line (-1) and is_blank_line () do end

  -- Go to `cur_goalc' in that non-blank line.
  while not eolp () and get_goalc () < cur_goalc do
    move_char (1)
  end
end

function previous_line_indent ()
  local cur_indent
  local m = point_marker ()

  move_line (-1)
  beginning_of_line ()

  -- Find first non-blank char.
  while not eolp () and following_char ():match ("%s") do
    move_char (1)
  end

  cur_indent = get_goalc ()

  -- Restore point.
  goto_offset (m.o)
  unchain_marker (m)

  return cur_indent
end
