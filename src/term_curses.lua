-- Curses terminal
--
-- Copyright (c) 2009-2012 Free Software Foundation, Inc.
--
-- This file is part of GNU Zi.
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

local ESC      = 0x1b
local ESCDELAY = 500

local resumed = true

local function keypad (on)
  local capstr = curses.tigetstr (on and "smkx" or "rmkx")
  if capstr then
    io.stdout:write (capstr)
    io.stdout:flush ()
  end
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

  -- from curses key presses to zi keycodes
  codetokey = tree.new ()

  -- from zi keycodes back to curses keypresses
  keytocode = {}

  -- Starting with specially named keys:
  for code, key in pairs {
    [0x9]     = "tab",
    [0xa]     = "enter",
    [0xd]     = "return",
    [0x20]    = "space",
    [0x5c]    = "backslash",
    [0x7f]    = "c-?",
    ["kdch1"] = "delete",
    ["kcud1"] = "down",
    ["kend"]  = "end",
    ["kf1"]   = "f1",
    ["kf2"]   = "f2",
    ["kf3"]   = "f3",
    ["kf4"]   = "f4",
    ["kf5"]   = "f5",
    ["kf6"]   = "f6",
    ["kf7"]   = "f7",
    ["kf8"]   = "f8",
    ["kf9"]   = "f9",
    ["kf10"]  = "f10",
    ["kf11"]  = "f11",
    ["kf12"]  = "f12",
    ["khome"] = "home",
    ["kich1"] = "insert",
    ["kcub1"] = "left",
    ["knp"]   = "pgdn",
    ["kpp"]   = "pgup",
    ["kcuf1"] = "right",
    ["kspd"]  = "c-z",
    ["kcuu1"] = "up"
  } do
    local codes = nil
    if type (code) == "string" then
      local s = curses.tigetstr (code)
      if s then
        codes = {}
        for i=1,#s do
          table.insert (codes, s:byte (i))
        end
      end
    else
      codes = {code}
    end

    if codes then
      key = keycode (key)
      keytocode[key]   = codes
      codetokey[codes] = key
    end
  end

  -- Reverse lookup of a lone ESC.
  keytocode[keycode "escape"] = { ESC }

  local kbs = curses.tigetstr ("kbs")
  if kbs and kbs ~= 0x08 then
    -- using 0x08 (^H) for backspace hangs with C-qC-h
    keytocode[keycode "backspace"] = {kbs}
    codetokey[{kbs}] = "backspace"
  else
    -- ...fallback on 0x7f for backspace if terminfo doesn't know better
    keytocode[keycode "backspace"] = {0x7f}
  end
  codetokey[{0x7f}] = keycode "backspace"

  -- ...inject remaining ASCII key codes
  for code=0,0xff do
    local key = nil
    if not codetokey[{code}] then
      -- control keys
      if code < 0x20 then
        key = keycode ("c-" .. string.lower (string.char (code + 0x40)))

      -- printable keys
      elseif code < 0x80 then
        key = keycode (string.char (code))

      -- alt keys
      else
        local basekey = codetokey[{code - 0x80}]
        if type (basekey) == "table" and basekey.key then
          key = "a-" + basekey
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

function term_close ()
  -- Revert terminal to cursor mode before exiting.
  keypad (false)

  curses.endwin ()
end

function term_reopen ()
  curses.flushinp ()
  -- FIXME: implement def_shell_mode in lcurses
  --curses.def_shell_mode ()
  curses.doupdate ()
  resumed = true
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
  if c == ESC then
    -- Detecting ESC is tricky...
    c = term_getkey_unfiltered (ESCDELAY)
    if c == nil then
      -- ...if nothing follows quickly enough, assume ESC keypress...
      key = keycode "escape"
    else
      -- ...see whether the following chars match an escape sequence...
      codes = { ESC }
      while true do
        table.insert (codes, c)
        key = codetokey[codes]
        if key and key.key then
          -- ...return the codes for the matched escape sequence.
          break
        elseif key == nil then
          -- ...no match, rebuffer unmatched chars and return ESC.
          unget_codes (list.tail (codes))
          key = keycode "escape"
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

  if key == keycode "escape" then
    local another = term_getkey (GETKEY_DEFAULT)
    if another then key = "a-" + another end
  end

  return key
end


-- If key can be represented as an ASCII byte, return it, otherwise
-- return nil.
function term_keytobyte (key)
  local codes = keytocode[key]
  if codes and  #codes == 1 and 0xff >= codes[1] then
    return codes[1]
  end
  return nil
end


function term_bytetokey (byte)
  if byte == ESC then
    return keycode "\\e"
  else
    return codetokey[byte]
  end
end


function term_ungetkey (key)
  local codevec = {}

  if key ~= nil then
    if key.ALT then
      codevec = { ESC }
      key = key - "a-"
    end

    local code = keytocode[key]
    if code then
      codevec = list.concat (codevec, code)
    end
  end

  unget_codes (codevec)
end

local usedpairs

local init_pair = memoize (function (fg, bg)
  local r
  if curses.has_colors () then
    if not usedpairs then
      curses.start_color ()
      curses.use_default_colors ()
      usedpairs = 0
    end

    -- FIXME: fallback to white on black if use_default_colors is not available
    if fg == -1 and bg == -1 then
      return curses.color_pair (0)
    else
      usedpairs = usedpairs + 1
      curses.init_pair (usedpairs, fg, bg)
      return curses.color_pair (usedpairs)
    end
  end

  return 0
end
)

function term_get_attribute (settings)
  if not settings then return nil end

  local attr = 0
  if type (settings) == "string" and settings:match "#%x+" then
    -- FIXME: color strings not yet implemented
  elseif type (settings) == "string" then
    if display[settings] then
      attr = bit32.bor (attr, init_pair (display[settings], -1))
    end
  else
    local fg = settings.foreground and display[settings.foreground] or -1
    local bg = settings.background and display[settings.background] or -1
    attr = bit32.bor (attr, init_pair (fg, bg))

    if settings.fontStyle then
      for w in settings.fontStyle:gmatch "%S+" do
        attr = bit32.bor (attr, display[w] or 0)
      end
    end
  end

  return attr
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

function term_addch (c)
  curses.stdscr ():addch (c)
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
