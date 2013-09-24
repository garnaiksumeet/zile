-- Getting and ungetting key strokes
--
-- Copyright (c) 2010-2012 Free Software Foundation, Inc.
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

-- Maximum time to avoid screen updates when catching up with buffered
-- input, in milliseconds.
local MAX_RESYNC_MS = 500

local _last_key

-- Return last key pressed
function lastkey ()
  return _last_key
end

-- Get a keystroke, waiting for up to delay ms, and translate it into a
-- keycode.
function getkeystroke (delay)
  _last_key = term_getkey (delay)

  if _last_key and thisflag.defining_macro then
    add_key_to_cmd (_last_key)
  end

  return _last_key
end

-- Return the next keystroke, refreshing the screen only when the input
-- buffer is empty, or MAX_RESYNC_MS have elapsed since the last
-- screen refresh.
local next_refresh = {}
local refresh_wait = {
  sec  = math.floor (MAX_RESYNC_MS / 1000),
  usec = (MAX_RESYNC_MS % 1000) * 1000,
}

function getkey (delay)
  local now = posix.gettimeofday ()
  local keycode = getkeystroke (0)

  if not keycode or posix.timercmp (now, next_refresh) >= 0 then
    term_redisplay ()
    term_refresh ()
    next_refresh = posix.timeradd (now, refresh_wait)
  end

  -- finish highlighting active window buffer while waiting for a key
  local bp = cur_wp.bp
  while not keycode and syntax_next_line (bp, bp.syntax.dirty or 0) do
    keycode = getkeystroke (0)
  end

  if not keycode then
    keycode = getkeystroke (delay)
  end

  return keycode
end

function getkey_unfiltered (delay)
  local c = term_getkey_unfiltered (delay)
  _last_key = c
  if thisflag.defining_macro then
    add_key_to_cmd (c)
  end
  return c
end

-- Wait for GETKEY_DELAYED ms or until a key is pressed.
-- The key is then available with getkey.
function waitkey ()
  ungetkey (getkey (GETKEY_DELAYED))
end

-- Push a key into the input buffer.
function pushkey (key)
  term_ungetkey (key)
end

-- Unget a key as if it had not been fetched.
function ungetkey (key)
  pushkey (key)

  if thisflag.defining_macro then
    remove_key_from_cmd ()
  end
end
