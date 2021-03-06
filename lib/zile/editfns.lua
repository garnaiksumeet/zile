-- Useful editing functions
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

-- Signal an error, and abort any ongoing macro definition.
function ding ()
  if thisflag.defining_macro then
    cancel_kbd_macro ()
  end

  if eval.get_variable ("ring_bell") and cur_wp then
    term_beep ()
  end
  -- enable call chaining with `return ding ()'
  return false
end


function is_empty_line ()
  return buffer_line_len (cur_bp) == 0
end

function is_blank_line ()
  return tostring (get_buffer_region (cur_bp, region_new (get_buffer_line_o (cur_bp), buffer_end_of_line (cur_bp, get_buffer_pt (cur_bp))))):match ("^%s*$") ~= nil
end

-- Returns the character following point in the current buffer.
function following_char ()
  if eobp () then
    return nil
  elseif eolp () then
    return '\n'
  else
    return get_buffer_char (cur_bp, get_buffer_pt (cur_bp))
  end
end

-- Return the character preceding point in the current buffer.
function preceding_char ()
  if bobp () then
    return nil
  elseif bolp () then
    return '\n'
  else
    return get_buffer_char (cur_bp, get_buffer_pt (cur_bp) - 1)
  end
end

-- Return true if point is at the beginning of the buffer.
function bobp ()
  return get_buffer_pt (cur_bp) == 1
end

-- Return true if point is at the end of the buffer.
function eobp (void)
  return get_buffer_pt (cur_bp) > get_buffer_size (cur_bp)
end

-- Return true if point is at the beginning of a line.
function bolp ()
  return get_buffer_pt (cur_bp) == get_buffer_line_o (cur_bp)
end

-- Return true if point is at the end of a line.
function eolp ()
  return get_buffer_pt (cur_bp) - get_buffer_line_o (cur_bp) == buffer_line_len (cur_bp)
end
