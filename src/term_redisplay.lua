-- Redisplay engine
--
-- Copyright (c) 2009-2012 Free Software Foundation, Inc.
--
-- This file is part of GNU Zile.
--
-- GNU Zile is free software; you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 3, or (at your option)
-- any later version.
--
-- GNU Zile is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
-- General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with GNU Zile; see the file COPYING.  If not, write to the
-- Free Software Foundation, Fifth Floor, 51 Franklin Street, Boston,
-- MA 02111-1301, USA.

local width, height = 0, 0

function term_width ()
  return width
end

function term_height ()
  return height
end

function term_set_size (cols, rows)
  width = cols
  height = rows
end

-- Tidy up the term ready to leave Zile (temporarily or permanently!).
function term_tidy ()
  term_move (term_height () - 1, 0)
  term_clrtoeol ()
  term_attrset (FONT_NORMAL)
  term_refresh ()
end

-- Tidy and close the terminal ready to leave Zile.
function term_finish ()
  term_tidy ()
  term_close ()
end

-- Add a string to the terminal
function term_addstr (s)
  for i = 1, #s do
    term_addch (string.byte (s, i))
  end
end

local function make_char_printable (c)
  if c >= 0 and c <= 27 then
    return string.format ("^%c", string.byte ("@") + c)
  else
    return string.format ("\\%o", bit.band (c, 0xff))
  end
end

local cur_tab_width = 0

local function outch (c, font, x)
  local tw = term_width ()

  if x >= tw then
    return x
  end

  term_attrset (font)

  if c == string.byte ('\t') then
    for w = cur_tab_width - x % cur_tab_width, 1, -1 do
      term_addstr (' ')
      x = x + 1
      if x >= tw then
        break
      end
    end
  elseif posix.isprint (string.char (c)) then
    term_addch (c)
    x = x + 1
  else
    local s = make_char_printable (c)
    local j = #s
    for i = 1, j do
      term_addch (string.byte (s, i))
      x = x + 1
      if x >= tw then
        break
      end
    end
  end

  term_attrset (FONT_NORMAL)

  return x
end

local function draw_end_of_line (line, wp, lineno, rp, highlight, x, i)
  if x >= term_width () then
    term_move (line, term_width () - 1)
    term_addstr ('$')
  elseif highlight == true then
    while x < wp.ewidth do
      if in_region (lineno, i, rp) then
        x = outch (string.byte (' '), FONT_REVERSE, x)
      else
        x = x + 1
      end
      i = i + 1
    end
  end
end

local function draw_line (line, startcol, wp, o, lineno, rp, highlight)
  term_move (line, 0)
  local x = 0
  for i = startcol + 1, estr_end_of_line (get_buffer_text (wp.bp), o) - o do
    if x >= wp.ewidth then
      break
    end
    local font = FONT_NORMAL
    if highlight and in_region (lineno, i, rp) then
      font = FONT_REVERSE
    end
    x = outch (string.byte (get_buffer_text (wp.bp).s[o + i]), font, x)
  end

  draw_end_of_line (line, wp, lineno, rp, highlight, x, x + startcol)
end

local function calculate_highlight_region (wp, rp)
  if (wp ~= cur_wp and not get_variable_bool ("highlight-nonselected-windows"))
    or (wp.bp.mark == nil)
    or not wp.bp.mark_active then
    return false
  end

  rp.start = point_to_offset (wp.bp, window_pt (wp))
  rp.finish = wp.bp.mark.o
  if rp.finish < rp.start then
    local o = rp.start
    rp.start = rp.finish
    rp.finish = o
  end
  return true
end

local function draw_window (topline, wp)
  local rp = {}
  local highlight = calculate_highlight_region (wp, rp)

  -- Find the first line to display on the first screen line.
  local pt = window_pt (wp)
  local lineno = pt.n
  local o = get_buffer_line_o (wp.bp)
  for i = wp.topdelta, 1, -1 do
    o = estr_prev_line (get_buffer_text (wp.bp), o)
    lineno = lineno - 1
  end

  cur_tab_width = tab_width (wp.bp)

  -- Draw the window lines.
  for i = topline, wp.eheight + topline do
    -- Clear the line.
    term_move (i, 0)
    term_clrtoeol ()

    -- If at the end of the buffer, don't write any text.
    if o ~= nil then
      draw_line (i, wp.start_column, wp, o, lineno, rp, highlight)

      if wp.start_column > 0 then
        term_move (i, 0)
        term_addstr ('$')
      end

      o = estr_next_line (get_buffer_text (wp.bp), o)
      lineno = lineno + 1
    end
  end

  wp.all_displayed = o == nil or o == get_buffer_size (wp.bp)
end

function make_modeline_flags (wp)
  if wp.bp.modified and wp.bp.readonly then
    return "%*"
  elseif wp.bp.modified then
    return "**"
  elseif wp.bp.readonly then
    return "%%"
  end
  return "--"
end

local point_screen_column = 0

-- This function calculates the best start column to draw if the line
-- at point has to be truncated.
local function calculate_start_column (wp)
  local t = tab_width (wp.bp)
  local pt = window_pt (wp)
  local o = point_to_offset (cur_bp, pt) - pt.o
  local rpfact = math.floor (pt.o / math.floor (wp.ewidth / 3))

  local col = 0
  local lastcol = 0
  for lp = pt.o, 0, -1 do
    col = 0
    for p = lp, pt.o - 1 do
      local c = get_buffer_text (wp.bp).s[o + p + 1]
      if c == '\t' then
        col = bit.bor (col, t - 1) + 1
      elseif posix.isprint (c) then
        col = col + 1
      else
        col = col + #make_char_printable (string.byte (c))
      end
    end

    local lpfact = math.floor (lp / math.floor (wp.ewidth / 3))

    if col >= wp.ewidth - 1 or lpfact < rpfact - 2 then
      wp.start_column = lp + 1
      point_screen_column = lastcol
      return
    end

    lastcol = col
  end

  wp.start_column = 0
  point_screen_column = col
end

local function make_screen_pos (wp)
  local tv = window_top_visible (wp)
  local bv = window_bottom_visible (wp)

  if tv and bv then
    return "All"
  elseif tv then
    return "Top"
  elseif bv then
    return "Bot"
  end
  return string.format ("%2d%%", (window_pt (wp).n - wp.topdelta) / offset_to_point (wp.bp, get_buffer_size (wp.bp)).n * 100)
end

local function draw_status_line (line, wp)
  local pt = window_pt (wp)
  term_attrset (FONT_REVERSE)
  term_move (line, 0)
  term_addstr (string.rep ('-', wp.ewidth))

  local eol_type
  if get_buffer_text (cur_bp).eol == coding_eol_cr then
    eol_type = "(Mac)"
  elseif get_buffer_text (cur_bp).eol == coding_eol_crlf then
    eol_type = "(DOS)"
  else
    eol_type = ":"
  end

  term_move (line, 0)

  local bs = string.format ("(%d,%d)", pt.n + 1, get_goalc_bp (wp.bp, pt))
  local as = string.format ("--%s%2s  %-15s   %s %-9s (Fundamental",
                            eol_type, make_modeline_flags (wp), wp.bp.name, make_screen_pos (wp), bs)

  if wp.bp.autofill then
    as = as .. " Fill"
  end
  if thisflag.defining_macro then
    as = as .. " Def"
  end
  if wp.bp.isearch then
    as = as .. " Isearch"
  end
  as = as .. ")"

  term_addstr (string.sub (as, 1, term_width ()))
  term_attrset (FONT_NORMAL)
end

local cur_topline = 0

function term_redisplay ()
  local topline = 0

  cur_topline = topline

  calculate_start_column (cur_wp)

  for _, wp in ipairs (windows) do
    if wp == cur_wp then
      cur_topline = topline
    end

    draw_window (topline, wp)

    -- Draw the status line only if there is available space after the
    -- buffer text space.
    if wp.fheight > wp.eheight then
      draw_status_line (topline + wp.eheight, wp)
    end

    topline = topline + wp.fheight
  end

  term_redraw_cursor ()
end

function term_redraw_cursor ()
  -- Redraw cursor.
  term_move (cur_topline + cur_wp.topdelta, point_screen_column)
end

function term_full_redisplay ()
  term_clear ()
  term_redisplay ()
end
