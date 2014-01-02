-- Curses terminal
--
-- Copyright (c) 2009-2014 Free Software Foundation, Inc.
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

local codetokey, keytocode, key_buf

-- ASCII character codes:
local ASC_BS  = 0x08
local ASC_TAB = 0x09
local ASC_RET = 0x0d
local ASC_SP  = 0x20
local ASC_A   = 0x41
local ASC_ESC = 0x1b
local ASC_BSL = 0x5c
local ASC_DEL = 0x7f

local ESCDELAY = 500

local resumed = true

local function keypad (on)
  local capstr = curses.tigetstr (on and "smkx" or "rmkx")
  if capstr then
    io.stdout:write (capstr)
    io.stdout:flush ()
  end
end

local function tigetvec (cap)
  local vec = nil
  local s = curses.tigetstr (cap)
  if s then
    vec = {}
    for i = 1, #s do
      table.insert (vec, s:byte (i))
    end
  end
  return vec
end

function term_init ()
  curses.initscr ()

  display = {
    normal    = curses.A_NORMAL,
    standout  = curses.A_STANDOUT,
    underline = curses.A_UNDERLINE,
    reverse   = curses.A_REVERSE,
    blink     = curses.A_BLINK,
    dim       = curses.A_DIM,
    bold      = curses.A_BOLD,
    protect   = curses.A_PROTECT,
    invisible = curses.A_INVIS,

    black   = curses.COLOR_BLACK,
    red     = curses.COLOR_RED,
    green   = curses.COLOR_GREEN,
    yellow  = curses.COLOR_YELLOW,
    blue    = curses.COLOR_BLUE,
    magenta = curses.COLOR_MAGENTA,
    cyan    = curses.COLOR_CYAN,
    white   = curses.COLOR_WHITE,
  }

  key_buf = {}

  -- from curses key presses to zile keycodes
  codetokey = tree.new ()

  -- from zile keycodes back to curses keypresses
  keytocode = {}

  -- Starting with specially named keys:
  local codes
  for code, key in pairs {
    [ASC_TAB] = "\\TAB",
    [ASC_RET] = "\\RET",
    [ASC_SP]  = "\\SPC",
    [ASC_BSL] = "\\\\",
    [ASC_DEL] = "\\C-?",
    ["kdch1"] = "\\DELETE",
    ["kcud1"] = "\\DOWN",
    ["kend"]  = "\\END",
    ["kf1"]   = "\\F1",
    ["kf2"]   = "\\F2",
    ["kf3"]   = "\\F3",
    ["kf4"]   = "\\F4",
    ["kf5"]   = "\\F5",
    ["kf6"]   = "\\F6",
    ["kf7"]   = "\\F7",
    ["kf8"]   = "\\F8",
    ["kf9"]   = "\\F9",
    ["kf10"]  = "\\F10",
    ["kf11"]  = "\\F11",
    ["kf12"]  = "\\F12",
    ["khome"] = "\\HOME",
    ["kich1"] = "\\INSERT",
    ["kcub1"] = "\\LEFT",
    ["knp"]   = "\\PAGEDOWN",
    ["kpp"]   = "\\PAGEUP",
    ["kcuf1"] = "\\RIGHT",
    ["kspd"]  = "\\C-z",
    ["kcuu1"] = "\\UP"
  } do
    codes = type (code) == "string" and tigetvec (code) or {code}
    if codes then
      key = keycode (key)
      keytocode[key]   = codes
      codetokey[codes] = key
    end
  end

  -- Reverse lookup of a lone ESC.
  keytocode[keycode "\\ESC"] = { ASC_ESC }

  -- Using 0x08 (^H) for \BACKSPACE hangs with C-qC-h, so when terminfo
  -- tries to use 0x08 as \BACKSPACE, fallback to  0x7f (^?) instead.
  local kbs = curses.tigetstr ("kbs")
  codes = {ASC_DEL}
  if kbs and kbs ~= string.char (ASC_BS) then
    codes = tigetvec ("kbs")
  end
  if codes then
    keytocode[keycode "\\BACKSPACE"] = codes
    codetokey[codes] = keycode "\\BACKSPACE"
  end

  -- ...inject remaining ASCII key codes
  for code = 0, ASC_DEL do
    local key = nil
    if not codetokey[{code}] then
      -- control keys
      if code < ASC_SP then
        key = keycode ("\\C-" .. string.lower (string.char (code + ASC_A - 1)))

      -- printable keys
      elseif code < (1+ ASC_DEL) then
        key = keycode (string.char (code))

      -- meta keys
      else
        local basekey = codetokey[{code - (1+ ASC_DEL)}]
        if type (basekey) == "table" and basekey.key then
          key = "\\M-" + basekey
        end
      end

      if key ~= nil then
        codetokey[{code}] = key
        keytocode[key]    = {code}
      end
    end
  end

  curses.echo (false)
  curses.nl (false)
  curses.raw (true)
  curses.stdscr ():meta (true)
  curses.stdscr ():intrflush (false)
  curses.stdscr ():keypad (false)

  posix.signal (posix.SIGCONT, function () resumed = true end)
end

function term_resize (nlines, ncols)
  -- With a traditional curses, resizeterm is not implemented.
  return pcall (curses.resizeterm, nlines, ncols)
end

function term_close ()
  -- Revert terminal to cursor mode before exiting.
  keypad (false)

  curses.endwin ()
end

function term_getkey_unfiltered (delay)
  if #key_buf > 0 then
    return table.remove (key_buf)
  end

  -- Put terminal in application mode if necessary.
  if resumed then
    keypad (true)
    resumed = nil
  end

  curses.stdscr ():timeout (delay)

  local c
  repeat
    c = curses.stdscr ():getch ()
    if curses.KEY_RESIZE == c then
      resize_windows ()
    end
  until curses.KEY_RESIZE ~= c

  return c
end

local function unget_codes (codes)
  key_buf = list.concat (key_buf, list.reverse (codes))
end

function term_getkey (delay)
  local codes, key = {}

  local c = term_getkey_unfiltered (delay)
  if c == ASC_ESC then
    -- Detecting ESC is tricky...
    c = term_getkey_unfiltered (ESCDELAY)
    if c == nil then
      -- ...if nothing follows quickly enough, assume ESC keypress...
      key = keycode "\\ESC"
    else
      -- ...see whether the following chars match an escape sequence...
      codes = { ASC_ESC }
      while true do
        table.insert (codes, c)
        key = codetokey[codes]
        if key and key.key then
          -- ...return the codes for the matched escape sequence.
          break
        elseif key == nil then
          -- ...no match, rebuffer unmatched chars and return ESC.
          unget_codes (list.tail (codes))
          key = keycode "\\ESC"
          break
        end
        -- ...partial match, fetch another char and try again.
        c = term_getkey_unfiltered (GETKEY_DEFAULT)
      end
    end
  else
    -- Detecting non-ESC involves fetching chars and matching...
    while true do
      table.insert (codes, c)
      key = codetokey[codes]
      if key and key.key then
        -- ...code lookup matched a key, return it.
        break
      elseif key == nil then
        -- ...or return nil for an invalid lookup code.
        key = nil
        break
      end
      -- ...for a partial match, fetch another char and try again.
      c = term_getkey_unfiltered (GETKEY_DEFAULT)
    end
  end

  if key == keycode "\\ESC" then
    local another = term_getkey (GETKEY_DEFAULT)
    if another then key = "\\M-" + another end
  end

  return key
end


-- If key can be represented as an ASCII byte, return it, otherwise
-- return nil.
function term_keytobyte (key)
  local codes = keytocode[key]
  if codes and #codes == 1 and 0xff >= codes[1] then
    return codes[1]
  end
  return nil
end


function term_bytetokey (byte)
  if byte == ASC_ESC then
    return keycode "\\ESC"
  else
    return codetokey[byte]
  end
end


function term_ungetkey (key)
  local codevec = {}

  if key ~= nil then
    if key.META then
      codevec = { ASC_ESC }
      key = key - "\\M-"
    end

    local code = keytocode[key]
    if code then
      codevec = list.concat (codevec, code)
    end
  end

  unget_codes (codevec)
end

function term_buf_len ()
  return #key_buf
end

function term_move (y, x)
  curses.stdscr ():move (y, x)
end

function term_clrtoeol ()
  curses.stdscr ():clrtoeol ()
end

function term_refresh ()
  curses.stdscr ():refresh ()
end

function term_clear ()
  curses.stdscr ():clear ()
end

function term_addstr (s)
  curses.stdscr ():addstr (s)
end

function term_attrset (attrs)
  curses.stdscr ():attrset (attrs or 0)
end

function term_beep ()
  curses.beep ()
end

function term_width ()
  return curses.cols ()
end

function term_height ()
  return curses.lines ()
end
