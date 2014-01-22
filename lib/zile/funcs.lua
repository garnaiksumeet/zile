-- Miscellaneous Emacs functions
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

local FileString = require "zile.FileString"

function get_region ()
  activate_mark ()
  return get_buffer_region (cur_bp, calculate_the_region ())
end

function write_temp_buffer (name, show, func, ...)
  local old_wp = cur_wp
  local old_bp = cur_bp

  -- Popup a window with the buffer "name".
  local wp = find_window (name)
  if show and wp then
    set_current_window (wp)
  else
    local bp = get_buffer (name)
    if show then
      set_current_window (popup_window ())
    end
    if bp == nil then
      bp = buffer_new ()
      bp.name = name
    end
    switch_to_buffer (bp)
  end

  -- Remove the contents of that buffer.
  local new_bp = buffer_new ()
  new_bp.name = cur_bp.name
  kill_buffer (cur_bp)
  cur_bp = new_bp
  cur_wp.bp = cur_bp

  -- Make the buffer a temporary one.
  cur_bp.needname = true
  cur_bp.noundo = true
  cur_bp.nosave = true
  set_temporary_buffer (cur_bp)

  -- Use the "callback" routine.
  func (...)

  goto_offset (1)
  cur_bp.readonly = true
  cur_bp.modified = false

  -- Restore old current window.
  set_current_window (old_wp)

  -- If we're not showing the new buffer, switch back to the old one.
  if not show then
    switch_to_buffer (old_bp)
  end
end

--- Run a shell command in a unix pipe.
-- @param cmd a shell command
-- @param output buffer for output, or t for current buffer
-- @param replace whether to replace original region
-- @param input optional input to CMD
-- @return true if CMD worked
function pipe_command (cmd, output, replace, input)
  local ok = true
  local tempfile = "/dev/null"

  if input then
    tempfile = os.tmpname ()

    local fd = io.open (tempfile, 'w')
    if not fd then
      return  minibuf_error ('Cannot open temporary file')
    end

    local written, err = fd:write (input)
    if not written then
      ok = minibuf_error ('Error writing to temporary file: ' .. err)
    end

    fd:close ()
  end

  local out
  if ok then
    local cmdline = string.format ("%s 2>&1 <%s", cmd, tempfile)
    local pipe = io.popen (cmdline, "r")
    if not pipe then
      ok = minibuf_error ("Cannot open pipe to process")
    else
      out = pipe:read ("*a")
      pipe:close ()
    end
  end

  if ok then
    local eol = string.find (out, "\n")

    if #out == 0 then
      minibuf_echo ("(Shell command succeeded with no output)")
    else
      if output == nil then
        local more_than_one_line = eol and eol ~= #out
        write_temp_buffer ("*Shell Command Output*", more_than_one_line, insert_string, out)
        if not more_than_one_line then
          minibuf_echo (out)
        end
      else
        local bp = get_buffer (output) or cur_bp
        local del = 0
        if replace and not warn_if_no_mark (bp) then
          local r = calculate_the_region (bp)
          goto_offset (r.start, bp)
          del = get_region_size (r)
        end
        replace_estr (del, FileString (out, coding_eol_lf), bp)
      end
    end
  end

  if tempfile ~= "/dev/null" then os.remove (tempfile) end
  return ok
end


function minibuf_read_shell_command ()
  local ms = minibuf_read ("Shell command: ", "")

  if not ms then
    keyboard_quit ()
    return
  end
  if ms == "" then
    return
  end

  return ms
end

function previous_line ()
  return move_line (-1)
end

function next_line ()
  return move_line (1)
end

-- Move through balanced expressions (sexps)
function move_sexp (dir)
  local gotsexp, level = false, 0
  local gotsexp, single_quote, double_quote = false, dir < 0, dir < 0

  local function isopenbracketchar (c)
    return (c == '(') or (c == '[') or (c == '{') or ((c == '\"') and not double_quote) or ((c == '\'') and not single_quote)
  end

  local function isclosebracketchar (c)
    return (c == ')') or (c == ']') or (c == '}') or ((c == '\"') and double_quote) or ((c == '\'') and single_quote)
  end

  while true do
    while not (dir > 0 and eolp or bolp) () do
      local o = get_buffer_pt (cur_bp) - (dir < 0 and 1 or 0)
      local c = get_buffer_char (cur_bp, o)

      -- Skip escaped quotes.
      if (c == '"' or c == '\'') and o > get_buffer_line_o (cur_bp) and get_buffer_char (cur_bp, o - 1) == '\\' then
        move_char (dir)
        c = 'a' -- Treat ' and " like word chars.
      end

      if (dir > 0 and isopenbracketchar or isclosebracketchar) (c) then
        if level == 0 and gotsexp then
          return true
        end

        level = level + 1
        gotsexp = true
        if c == '\"' then
          double_quote = not double_quote
        end
        if c == '\'' then
          single_quote = not single_quote
        end
      elseif (dir > 0 and isclosebracketchar or isopenbracketchar) (c) then
        if level == 0 and gotsexp then
          return true
        end

        level = level - 1
        gotsexp = true
        if c == '\"' then
          double_quote = not double_quote
        end
        if c == '\'' then
          single_quote = not single_quote
        end
        if level < 0 then
          return minibuf_error ("Scan error: \"Containing expression ends prematurely\"")
        end
      end

      move_char (dir)

      if not c:match ("[%a_$]") then
        if gotsexp and level == 0 then
          if not (isopenbracketchar (c) or isclosebracketchar (c)) then
            move_char (-dir)
          end
          return true
        end
      else
        gotsexp = true
      end
    end
    if gotsexp and level == 0 then
      return true
    end
    if not (dir > 0 and next_line or previous_line) () then
      if level ~= 0 then
        minibuf_error ("Scan error: \"Unbalanced parentheses\"")
      end
      return false
    end
    if dir > 0 then
      beginning_of_line ()
    else
      end_of_line ()
    end
  end
  return false
end


-- Move through words
local function iswordchar (c)
  return c and (c:match ("[%w$]"))
end

function move_word (dir)
  local gotword = false
  repeat
    while not (dir > 0 and eolp or bolp) () do
      if iswordchar (get_buffer_char (cur_bp, get_buffer_pt (cur_bp) - (dir < 0 and 1 or 0))) then
        gotword = true
      elseif gotword then
        break
      end
      move_char (dir)
    end
  until gotword or not move_char (dir)
  return gotword
end

function setcase_word (rcase)
  if not iswordchar (following_char ()) then
    if not move_word (1) or not move_word (-1) then
      return false
    end
  end

  local as = ""
  for i = get_buffer_pt (cur_bp) - get_buffer_line_o (cur_bp), buffer_line_len (cur_bp) - 1 do
    local c = get_buffer_char (cur_bp, get_buffer_line_o (cur_bp) + i)
    if iswordchar (c) then
      as = as .. c
    else
      break
    end
  end

  if #as > 0 then
    replace_estr (#as, FileString (recase (as, rcase), coding_eol_lf))
  end

  cur_bp.modified = true

  return true
end

-- Set the region case.
function setcase_region (func)
  local rp = calculate_the_region ()

  if warn_if_readonly_buffer () or not rp then
    return false
  end

  undo_start_sequence ()

  local m = point_marker ()
  goto_offset (rp.start)
  for _ = get_region_size (rp), 1, -1 do
    local c = func (following_char ())
    delete_char ()
    insert_char (c)
  end
  goto_offset (m.o)
  unchain_marker (m)

  cur_bp.modified = true
  undo_end_sequence ()

  return true
end


-- Transpose functions
local function transpose_subr (move_func)
  -- For transpose-chars.
  if move_func == move_char and eolp () then
    move_func (-1)
  end
  -- For transpose-lines.
  if move_func == move_line and get_buffer_line_o (cur_bp) == 1 then
    move_func (1)
  end

  -- Backward.
  if not move_func (-1) then
    return minibuf_error ("Beginning of buffer")
  end

  -- Mark the beginning of first string.
  push_mark ()
  local m1 = point_marker ()

  -- Check to make sure we can go forwards twice.
  if not move_func (1) or not move_func (1) then
    if move_func == move_line then
      -- Add an empty line.
      end_of_line ()
      insert_newline ()
    else
      pop_mark ()
      goto_offset (m1.o)
      minibuf_error ("End of buffer")

      unchain_marker (m1)
      return false
    end
  end

  goto_offset (m1.o)

  -- Forward.
  move_func (1)

  -- Save and delete 1st marked region.
  local as1 = tostring (get_region ())

  delete_region (calculate_the_region ())

  -- Forward.
  move_func (1)

  -- For transpose-lines.
  local m2, as2
  if move_func == move_line then
    m2 = point_marker ()
  else
    -- Mark the end of second string.
    set_mark ()

    -- Backward.
    move_func (-1)
    m2 = point_marker ()

    -- Save and delete 2nd marked region.
    as2 = tostring (get_region ())
    delete_region (calculate_the_region ())
  end

  -- Insert the first string.
  goto_offset (m2.o)
  unchain_marker (m2)
  insert_string (as1)

  -- Insert the second string.
  if as2 then
    goto_offset (m1.o)
    insert_string (as2)
  end
  unchain_marker (m1)

  -- Restore mark.
  pop_mark ()
  deactivate_mark ()

  -- Move forward if necessary.
  if move_func ~= move_line then
    move_func (1)
  end

  return true
end

function transpose (uniarg, move)
  if warn_if_readonly_buffer () then
    return false
  end

  local ret = true
  undo_start_sequence ()
  for uni = 1, uniarg do
    ret = transpose_subr (move)
    if not ret then
      break
    end
  end
  undo_end_sequence ()

  return ret
end
