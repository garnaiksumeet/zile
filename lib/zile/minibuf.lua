-- Minibuffer
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

files_history = history_new ()

minibuf_contents = nil

-- Minibuffer wrapper functions.

function minibuf_refresh ()
  if cur_wp then
    if minibuf_contents then
      term_minibuf_write (minibuf_contents)
    end
    term_refresh ()
  end
end

-- Clear the minibuffer.
function minibuf_clear ()
  term_minibuf_write ("")
end

-- Write the specified string in the minibuffer.
function minibuf_write (s)
  if s ~= minibuf_contents then
    minibuf_contents = s
    minibuf_refresh ()
  end
end

-- Maintain *Messages* buffer with less than `message_log_max` lines
-- by trimming from the beginning of the buffer.
-- FIXME: One of the calls below corrupts the undo tree for cur_bp if
--        trim_messages is not called via `with_current_buffer()`.
local function trim_messages (bp, msg)
  bp = bp or cur_bp
  msg = msg or minibuf_contents

  bp.noundo = true
  bp.readonly = false
  goto_offset (get_buffer_size (bp) + 1, bp)
  replace_estr (0, FileString (msg .. "\n"), bp)
  bp.lines = (bp.lines or 0) + 1

  local max = eval.get_variable ("message_log_max")
  if type (max) == "number" then
    local kill_lines = bp.lines - tonumber (max)
    if kill_lines > 0 then
      goto_offset (1, bp)
      while kill_lines > 0 do
        local o = buffer_next_line (bp, get_buffer_pt (bp))
        if o == nil then break end
	goto_offset (o, bp)
	kill_lines = kill_lines -1
      end
      buffer_start_of_line (bp, get_buffer_pt (bp))
      local kill_chars = get_buffer_pt (bp) - 1
      goto_offset (1, bp)
      replace_estr (kill_chars, FileString "", bp)
      bp.lines = tonumber (max)
      goto_offset (get_buffer_size (bp) + 1, bp)
    end
  end
  bp.readonly = true
  bp.modified = false
end


-- Write the specified error string in the minibuffer, or to stderr in
-- batch mode, and signal an error.
function minibuf_error (s)
  if bflag then
    io.stderr:write (s .. "\n")
  else
    minibuf_write (s)
  end

  local max = eval.get_variable ("message_log_max") or "nil"
  if max ~= "nil" then
    local bp = get_buffer_create ("*Messages*", create_auto_buffer)
    with_current_buffer (bp, trim_messages, bp,
                         "call-interactively: " .. minibuf_contents)
  end
  return ding ()
end

-- Write the specified string to the minibuffer, or to stdout in batch
-- mode.
function minibuf_echo (s)
  if bflag then
    io.stdout:write (s .. "\n")
  else
    minibuf_write (s)
  end

  local max = eval.get_variable ("message_log_max") or "nil"
  if max ~= "nil" then
    local bp = get_buffer_create ("*Messages*", create_auto_buffer)
    with_current_buffer (bp, trim_messages)
  end
end

function keyboard_quit ()
  deactivate_mark ()
  return minibuf_error ("Quit")
end

-- Read a string from the minibuffer using a completion.
function minibuf_vread_completion (fmt, value, cp, hp, empty_err, invalid_err)
  local ms

  while true do
    ms = term_minibuf_read (fmt, value, -1, cp, hp)

    if not ms then -- Cancelled.
      keyboard_quit ()
      break
    elseif ms == "" then
      minibuf_error (empty_err)
      ms = nil
      break
    else
      -- Complete partial words if possible.
      local comp = completion_try (cp, ms)
      if comp == "match" then
        ms = cp.match
      elseif comp == "incomplete" then
        popup_completion (cp)
      end

      if set.member (set.new (cp.completions), ms) then
        if hp then
          add_history_element (hp, ms)
        end
        minibuf_clear ()
        break
      else
        minibuf_error (string.format (invalid_err, ms))
        waitkey ()
      end
    end
  end

  return ms
end

-- Read a filename from the minibuffer.
function minibuf_read_filename (fmt, name, file)
  if not file and #name > 0 and name[-1] ~= '/' then
    name = name .. '/'
  end
  name = canonicalize_filename (name)
  if name then
    name = compact_path (name)

    local pos = #name
    if file then
      pos  = pos - #file
    end
    name = term_minibuf_read (fmt, name, pos, completion_new (true), files_history)

    if name then
      name = canonicalize_filename (name)
      if name then
        add_history_element (files_history, name)
      end
    end
  end

  return name
end

function minibuf_read_yesno (fmt)
  local errmsg = "Please answer yes or no."
  local ret = nil

  local cp = completion_new ()
  cp.completions = {"no", "yes"}
  local ms = minibuf_vread_completion (fmt, "", cp, nil, errmsg, errmsg)

  if ms then
    ret = ms == "yes"
  end

  return ret
end

-- Read and return a single key from a list of KEYS.  EXTRA keys are also
-- accepted and returned, though not shown in the error message when no
-- accepted key is pressed.  In addition, C-g is always accepted, causing
-- this function to execute "keyboard-quit" and then return nil.
-- Note that KEYS in particular is a list and not a keyset, because we
-- want to prompt with the options in the same order as given!
function minibuf_read_key (fmt, keys, extra)
  local accept = list.concat (keys, extra)
  local errmsg = ""

  while true do
    minibuf_write (errmsg .. fmt .. " (" .. table.concat (keys, ", ") .. ") ")
    local key = getkeystroke (GETKEY_DEFAULT)

    if key == keycode "\\C-g" then
      keyboard_quit ()
      break
    elseif set.member (keyset (accept), key) then
      return key
    else
      errmsg = keys[#keys]
      if #keys > 1 then
        errmsg = table.concat (list.slice (keys, 1, -2), ", ") .. " or " .. errmsg
      end
      errmsg = "Please answer " .. errmsg .. ".  "
    end
  end
end

-- Read a string from the minibuffer.
function minibuf_read (fmt, value, cp, hp)
  return term_minibuf_read (fmt, value, -1, cp, hp)
end

-- Read a non-negative number from the minibuffer.
function minibuf_read_number (fmt)
  local n
  repeat
    local ms = minibuf_read (fmt, "")
      if not ms then
        keyboard_quit ()
        break
      elseif #ms == 0 then
        n = ""
      else
        n = tonumber (ms, 10)
      end
      if not n then
        minibuf_write ("Please enter a number.")
      end
  until n

  return n
end
