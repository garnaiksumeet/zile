-- Buffer-oriented functions
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


local FileString    = require "zile.FileString"
local MutableString = require "zile.MutableString"

-- Buffer methods that know about the gap.

function get_buffer_pre_point (bp)
  return bp.text:sub (1, get_buffer_pt (bp) - 1)
end

function get_buffer_post_point (bp)
  return bp.text:sub (get_buffer_pt (bp) + bp.gap)
end

function get_buffer_pt (bp)
  return bp.pt
end

local function set_buffer_pt (bp, o)
  if o < bp.pt then
    bp.text:move (o + bp.gap, o, bp.pt - o)
    bp.text:set (o, '\0', math.min (bp.pt - o, bp.gap))
  elseif o > bp.pt then
    bp.text:move (bp.pt, bp.pt + bp.gap, o - bp.pt)
    bp.text:set (o + bp.gap - math.min (o - bp.pt, bp.gap), '\0', math.min (o - bp.pt, bp.gap))
  end
  bp.pt = o
end

local function realo_to_o (bp, o)
  if o == nil then
    return o
  elseif o < bp.pt + bp.gap then
    return math.min (o, bp.pt)
  end
  return o - bp.gap
end

local function o_to_realo (bp, o)
  return o < bp.pt and o or o + bp.gap
end

function get_buffer_size (bp)
  return realo_to_o (bp, bp.text:bytes () + 1) - 1
end

function buffer_line_len (bp, o)
  o = o or get_buffer_line_o (bp)
  return realo_to_o (bp, bp.text:end_of_line (o_to_realo (bp, o))) -
    realo_to_o (bp, bp.text:start_of_line (o_to_realo (bp, o)))
end

-- Replace `del' chars after point with `es'.
local min_gap = 1024 -- Minimum gap size after resize
local max_gap = 4096 -- Maximum permitted gap size
function replace_estr (del, es, bp)
  bp = bp or cur_bp
  if warn_if_readonly_buffer (bp) then
    return false
  end

  if es.eol ~= get_buffer_eol (bp) then
    es = FileString ("", get_buffer_eol (bp)):cat (es)
  end

  local newlen = es:len (bp.text.eol)

  undo_save_block (bp.pt, del, newlen)

  -- Adjust gap.
  local oldgap = bp.gap
  local added_gap = 0
  if oldgap + del < newlen then
    -- If gap would vanish, open it to min_gap.
    added_gap = min_gap
    bp.text:insert (bp.pt, (es:bytes () + min_gap) - (bp.gap + del))
    bp.gap = min_gap
  elseif oldgap + del > max_gap + newlen then
    -- If gap would be larger than max_gap, restrict it to max_gap.
    bp.text:remove (bp.pt + newlen + max_gap, (oldgap + del) - (max_gap + newlen))
    bp.gap = max_gap
  else
    bp.gap = oldgap + del - newlen
  end

  -- Zero any new bit of gap not produced by insertion.
  if math.max (oldgap, newlen) + added_gap < bp.gap + newlen then
    bp.text:set (bp.pt + math.max (oldgap, newlen) + added_gap, '\0', newlen + bp.gap - math.max (oldgap, newlen) - added_gap)
  end

  -- Insert `newlen' chars.
  bp.text:replace (bp.pt, es)
  bp.pt = bp.pt + newlen

  -- Adjust markers.
  for m in pairs (bp.markers) do
    if m.o > cur_bp.pt - newlen then
      m.o = math.max (bp.pt - newlen, m.o + newlen - del)
    end
  end

  bp.modified = true
  if es:next_line (1) then
    thisflag.need_resync = true
  end
  return true
end

function insert_estr (es)
  return replace_estr (0, es)
end

function get_buffer_char (bp, o)
  local n = o_to_realo (bp, o)
  return string.char (bp.text[n])
end

function buffer_prev_line (bp, o)
  return realo_to_o (bp, bp.text:prev_line (o_to_realo (bp, o)))
end

function buffer_next_line (bp, o)
  return realo_to_o (bp, bp.text:next_line (o_to_realo (bp, o)))
end

function buffer_start_of_line (bp, o)
  return realo_to_o (bp, bp.text:start_of_line (o_to_realo (bp, o)))
end

function buffer_end_of_line (bp, o)
  return realo_to_o (bp, bp.text:end_of_line (o_to_realo (bp, o)))
end

function get_buffer_line_o (bp)
  return realo_to_o (bp, bp.text:start_of_line (o_to_realo (bp, bp.pt)))
end


-- Buffer methods that don't know about the gap.

function get_buffer_eol (bp)
  return bp.text.eol
end

-- Copy a region of text into an estr.
function get_buffer_region (bp, r)
  local s = ""
  if r.start < get_buffer_pt (bp) then
    s = s .. get_buffer_pre_point (bp):sub (r.start, math.min (r.finish, get_buffer_pt (bp)))
  end
  if r.finish > get_buffer_pt (bp) then
    local from = math.max (r.start - get_buffer_pt (bp), 0)
    s = s .. get_buffer_post_point (bp):sub (from + 1, r.finish - get_buffer_pt (bp))
  end
  return FileString (s, get_buffer_eol (bp))
end

-- Insert the character `c' at the current point position
-- into the current buffer.
function insert_char (c)
  return replace_estr (0, FileString (c))
end

function delete_char ()
  deactivate_mark ()

  if eobp () then
    return minibuf_error ("End of buffer")
  end

  if warn_if_readonly_buffer () then
    return false
  end

  if eolp () then
    replace_estr (#get_buffer_eol (cur_bp), FileString (""))
    thisflag.need_resync = true
  else
    replace_estr (1, FileString (""))
  end

  cur_bp.modified = true

  return true
end

function insert_buffer (bp)
  -- Copy text to avoid problems when bp == cur_bp.
  insert_estr (FileString (get_buffer_pre_point (bp) .. get_buffer_post_point (bp), get_buffer_eol (bp)))
end


-- The buffer list
buffers = {}

buffer_name_history = history_new ()

-- Allocate a new buffer, set the default local variable values, and
-- insert it into the buffer list.
function buffer_new ()
  local bp = {}

  bp.pt = 1
  bp.gap = 0
  bp.text = FileString (MutableString (""))
  bp.markers = {}
  bp.dir = posix.getcwd () or "" 

  -- Insert into buffer list.
  table.insert (buffers, bp)

  init_buffer (bp)

  return bp
end

-- Initialize buffer local variables.
function init_buffer (bp)
  if eval.get_variable ("auto_fill_mode", bp) then
    bp.autofill = true
  end
end

-- Get filename, or buffer name if nil.
function get_buffer_filename_or_name (bp)
  return bp.filename or bp.name
end

-- Set a new filename, and from it a name, for the buffer.
function set_buffer_names (bp, filename)
  if filename[1] ~= '/' then
    filename = string.format ("%s/%s", posix.getcwd(), filename)
  end
  bp.filename = filename

  local s = posix.basename (filename)
  local name = s
  local i = 2
  while get_buffer (name) do
    name = string.format ("%s<%d>", s, i)
    i = i + 1
  end
  bp.timestamp = posix.stat (filename,"mtime")
  bp.name = name
end

-- Search for a buffer named `name'.
function get_buffer (name)
  for _, bp in ipairs (buffers) do
    if bp.name == name then
      return bp
    end
  end
end

-- Return the buffer named `name`, creating a new one with `func` if
-- needed.
function get_buffer_create (name, func)
  func = func or get_buffer
  return get_buffer (name) or func (name)
end


local buffer_stack = {}

-- Push current buffer on a stack, and temporarily switch to `bp`.
function push_buffer (bp)
  table.insert (buffer_stack, cur_bp)
  cur_bp = bp
end

-- Unwind the entire buffer stack.
function unwind_buffer_stack ()
  while #buffer_stack > 0 do
    cur_bp = table.remove (buffer_stack)
  end
end

-- Temporarily switch buffers, without updating the interface.
function with_current_buffer (bp, func, ...)
  push_buffer (bp)
  local r = {func (...)}
  cur_bp = table.remove (buffer_stack)
  return table.unpack (r)
end

-- Switch to the specified buffer.
function switch_to_buffer (bp)
  assert (cur_wp.bp == cur_bp or cur_wp.bp == buffer_stack[1])

  -- The buffer is the current buffer; return safely.
  if cur_bp == bp then
    return
  end

  -- Set current buffer.
  cur_bp = bp
  cur_wp.bp = cur_bp

  -- Move the buffer to head.
  for i = 1, #buffers do
    if buffers[i] == bp then
      table.remove (buffers, i)
      table.insert (buffers, bp)
      break
    end
  end

  -- Change to buffer's default directory
  posix.chdir (bp.dir)

  -- If there is a pending buffer unwind, make sure we end up
  -- back here, and not in some previous "current" buffer.
  if #buffer_stack > 0 then
    buffer_stack[1] = cur_bp
  end

  thisflag.need_resync = true
end

-- Print an error message into the echo area and return true
-- if the current buffer is readonly; otherwise return false.
function warn_if_readonly_buffer (bp)
  bp = bp or cur_bp
  if bp.readonly then
    minibuf_error (string.format ("Buffer is readonly: %s", bp.name))
    return true
  end

  return false
end

function warn_if_no_mark (bp)
  bp = bp or cur_bp
  if not bp.mark then
    minibuf_error ("The mark is not set now")
    return true
  elseif not bp.mark_active then
    minibuf_error ("The mark is not active now")
    return true
  end
  return false
end

-- Make a region from two offsets
function region_new (o1, o2)
  return {start = math.min (o1, o2), finish = math.max (o1, o2)}
end

function get_region_size (rp)
  return rp.finish - rp.start
end

-- Return the region between point and mark.
function calculate_the_region (bp)
  bp = bp or cur_bp
  if warn_if_no_mark (bp) then
    return nil
  end

  return region_new (bp.pt, bp.mark.o)
end

function delete_region (r)
  if not r or warn_if_readonly_buffer () then
    return false
  end

  local m = point_marker ()
  goto_offset (r.start)
  replace_estr (get_region_size (r), FileString (""))
  goto_offset (m.o)
  unchain_marker (m)
  deactivate_mark ()

  return true
end

function in_region (o, x, r)
  return o + x >= r.start and o + x < r.finish
end

-- Set the specified buffer's temporary flag and move the buffer
-- to the end of the buffer list.
function set_temporary_buffer (bp)
  bp.temporary = true

  for i = 1, #buffers do
    if buffers[i] == bp then
      table.remove (buffers, i)
      break
    end
  end
  table.insert (buffers, 1, bp)
end

function activate_mark ()
  cur_bp.mark_active = true
end

function deactivate_mark ()
  cur_bp.mark_active = false
end

-- Return a safe tab width for the given buffer.
function tab_width (bp)
  return math.max (eval.get_variable ("tab_width", bp), 1)
end

function create_auto_buffer (name)
  local bp = buffer_new ()
  bp.name = name
  bp.needname = true
  bp.temporary = true
  bp.nosave = true
  return bp
end

function create_scratch_buffer ()
  return create_auto_buffer ("*scratch*")
end

-- Remove the specified buffer from the buffer list.
-- Recreate the scratch buffer when required.
function kill_buffer (kill_bp)
  -- Search for windows displaying the buffer to kill.
  for _, wp in ipairs (windows) do
    if wp.bp == kill_bp then
      wp.topdelta = 0
      wp.saved_pt = nil
    end
  end

  -- Remove the buffer from the buffer list.
  local next_bp = buffers[#buffers]
  for i = 1, #buffers do
    if buffers[i] == kill_bp then
      table.remove (buffers, i)
      next_bp = buffers[i > 1 and i - 1 or #buffers]
      if cur_bp == kill_bp then
        cur_bp = next_bp
      end
      break
    end
  end

  -- If no buffers left, recreate scratch buffer and point windows at
  -- it.
  if #buffers == 0 then
    table.insert (buffers, create_scratch_buffer ())
    cur_bp = buffers[1]
    for _, wp in ipairs (windows) do
      wp.bp = cur_bp
    end
  end

  -- Resync windows that need it.
  for _, wp in ipairs (windows) do
    if wp.bp == kill_bp then
      wp.bp = next_bp
      window_resync (wp)
    end
  end
end

function make_buffer_completion ()
  local cp = completion_new ()
  for _, bp in ipairs (buffers) do
    table.insert (cp.completions, bp.name)
  end

  return cp
end

-- Check if the buffer has been modified.  If so, asks the user if
-- he/she wants to save the changes.  If the response is positive, return
-- true, else false.
function check_modified_buffer (bp)
  if bp.modified and not bp.nosave then
    while true do
      local ans = minibuf_read_yesno (string.format ("Buffer %s modified; kill anyway? (yes or no) ", bp.name))
      if ans == nil then
        return keyboard_quit ()
      elseif not ans then
        return false
      end
      break
    end
  end

  return true
end


-- Basic movement routines

function beginning_of_line ()
  goto_offset (get_buffer_line_o (cur_bp))
  cur_bp.goalc = 0
end

function end_of_line ()
  goto_offset (get_buffer_line_o (cur_bp) + buffer_line_len (cur_bp))
  cur_bp.goalc = math.huge
end

function move_char (offset)
  local dir, ltest, btest, lmove
  if offset >= 0 then
    dir, ltest, btest, lmove = 1, eolp, eobp, beginning_of_line
  else
    dir, ltest, btest, lmove = -1, bolp, bobp, end_of_line
  end
  for i = 1, math.abs (offset) do
    if not ltest () then
      set_buffer_pt (cur_bp, get_buffer_pt (cur_bp) + dir)
    elseif not btest () then
      thisflag.need_resync = true
      set_buffer_pt (cur_bp, get_buffer_pt (cur_bp) + #get_buffer_eol (cur_bp) * dir)
      lmove ()
    else
      return false
    end
  end

  return true
end

-- Get the goal column, expanding tabs.
function get_goalc (bp, o)
  bp = bp or cur_bp
  o = o or get_buffer_pt (bp)

  local col = 0
  local t = tab_width (bp)
  local start = buffer_start_of_line (bp, o)
  for i = 0, o - start - 1 do
    if get_buffer_char (bp, start + i) == '\t' then
      col = bit32.bor (col, t - 1)
    end
    col = col + 1
  end

  return col
end

-- Go to the column `goalc'.  Take care of expanding tabulations.
function goto_goalc ()
  local col = 0

  local i = get_buffer_line_o (cur_bp)
  local lim = get_buffer_line_o (cur_bp) + buffer_line_len (cur_bp)
  while i < lim do
    if col == cur_bp.goalc then
      break
    elseif get_buffer_char (cur_bp, i) == '\t' then
      local t = tab_width (cur_bp)
      for w = t - col % t, 1, -1 do
        col = col + 1
        if col == cur_bp.goalc then
          break
        end
      end
    else
      col = col + 1
    end
    i = i + 1
  end

  set_buffer_pt (cur_bp, i)
end

function move_line (n)
  local func = buffer_next_line
  if n < 0 then
    n = -n
    func = buffer_prev_line
  end

  if not command.was_labelled ":move_line" then
    cur_bp.goalc = get_goalc ()
  end
  command.attach_label ":move_line"

  while n > 0 do
    local o = func (cur_bp, cur_bp.pt)
    if o == nil then
      break
    end
    set_buffer_pt (cur_bp, o)
    n = n - 1
  end

  goto_goalc ()
  thisflag.need_resync = true

  return n == 0
end

function offset_to_line (bp, offset)
  local n = 0
  local o = 1
  while buffer_end_of_line (bp, o) and buffer_end_of_line (bp, o) < offset do
    n = n + 1
    o = buffer_next_line (bp, o)
    assert (o)
  end
  return n
end

function goto_offset (o, bp)
  bp = bp or cur_bp
  local old_lineo = get_buffer_line_o (bp)
  set_buffer_pt (bp, o)
  if get_buffer_line_o (bp) ~= old_lineo then
    cur_bp.goalc = get_goalc ()
    thisflag.need_resync = true
  end
end

function buffer_next (this_bp)
  for i, bp in ipairs (buffers) do
    if bp == this_bp then
      if i > 1 then
        return buffers[i - 1]
      else
        return buffers[#buffers]
      end
      break
    end
  end
end
