-- Key encoding and decoding functions
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

-- Key modifiers.
local KBD_CTRL = 512
local KBD_META = 1024

-- Common non-alphanumeric keys.
local KBD_ESC = 27
local KBD_CANCEL = 257
local KBD_TAB = 258
local KBD_RET = 259
local KBD_PGUP = 260
local KBD_PGDN = 261
local KBD_HOME = 262
local KBD_END = 263
local KBD_DEL = 264
local KBD_BS = 265
local KBD_INS = 266
local KBD_LEFT = 267
local KBD_RIGHT = 268
local KBD_UP = 269
local KBD_DOWN = 270
local KBD_F1 = 272
local KBD_F2 = 273
local KBD_F3 = 274
local KBD_F4 = 275
local KBD_F5 = 276
local KBD_F6 = 277
local KBD_F7 = 278
local KBD_F8 = 279
local KBD_F9 = 280
local KBD_F10 = 281
local KBD_F11 = 282
local KBD_F12 = 283

local codetoname = {
  [KBD_ESC]   = "ESC",
  [KBD_PGUP]  = "<prior>",
  [KBD_PGDN]  = "<next>",
  [KBD_HOME]  = "<home>",
  [KBD_END]   = "<end>",
  [KBD_DEL]   = "<delete>",
  [KBD_BS]    = "<backspace>",
  [KBD_INS]   = "<insert>",
  [KBD_LEFT]  = "<left>",
  [KBD_RIGHT] = "<right>",
  [KBD_UP]    = "<up>",
  [KBD_DOWN]  = "<down>",
  [KBD_RET]   = "<RET>",
  [KBD_TAB]   = "<TAB>",
  [KBD_F1]    = "<f1>",
  [KBD_F2]    = "<f2>",
  [KBD_F3]    = "<f3>",
  [KBD_F4]    = "<f4>",
  [KBD_F5]    = "<f5>",
  [KBD_F6]    = "<f6>",
  [KBD_F7]    = "<f7>",
  [KBD_F8]    = "<f8>",
  [KBD_F9]    = "<f9>",
  [KBD_F10]   = "<f10>",
  [KBD_F11]   = "<f11>",
  [KBD_F12]   = "<f12>",
  [string.byte(' ')] = "SPC",
}


-- Array of key names
local keynametocode = {
  ["\\BACKSPACE"] = KBD_BS,
  ["\\C-"] = KBD_CTRL,
  ["\\DELETE"] = KBD_DEL,
  ["\\DOWN"] = KBD_DOWN,
  ["\\ESC"] = KBD_ESC,
  ["\\END"] = KBD_END,
  ["\\F1"] = KBD_F1,
  ["\\F10"] = KBD_F10,
  ["\\F11"] = KBD_F11,
  ["\\F12"] = KBD_F12,
  ["\\F2"] = KBD_F2,
  ["\\F3"] = KBD_F3,
  ["\\F4"] = KBD_F4,
  ["\\F5"] = KBD_F5,
  ["\\F6"] = KBD_F6,
  ["\\F7"] = KBD_F7,
  ["\\F8"] = KBD_F8,
  ["\\F9"] = KBD_F9,
  ["\\HOME"] = KBD_HOME,
  ["\\INSERT"] = KBD_INS,
  ["\\LEFT"] = KBD_LEFT,
  ["\\M-"] = KBD_META,
  ["\\PAGEDOWN"] = KBD_PGDN,
  ["\\PAGEUP"] = KBD_PGUP,
  ["\\RET"] = KBD_RET,
  ["\\RIGHT"] = KBD_RIGHT,
  ["\\SPC"] = string.byte (' '),
  ["\\TAB"] = KBD_TAB,
  ["\\UP"] = KBD_UP,
  ["\\\\"] = string.byte ('\\'),
}

-- Insert printable characters in the ASCII range.
for i = 0x0, 0x7f do
  if posix.isprint (string.char (i)) and i ~= string.byte ('\\') and i ~= string.byte (' ') then
    keynametocode[string.char (i)] = i
  end
end

local function mapkey (map, key, mod)
  if not key then
    return "invalid keycode: nil"
  end

  local s = (key.CTRL and mod.C or "") .. (key.META and mod.M or "")

  if not key.key then
    return "invalid keycode: " .. s .. "nil"
  end

  if map[key.key] then
    s = s .. map[key.key]
  elseif key.key <= 0xff and posix.isgraph (string.char (key.key)) then
    s = s .. string.char (key.key)
  else
    s = s .. string.format ("<%x>", key.key)
  end

  return s
end

local keyreadsyntax = table.invert (keynametocode)

-- Convert an internal format key chord back to its read syntax
local function toreadsyntax (key)
  return mapkey (keyreadsyntax, key, {C = "\\C-", M = "\\M-"})
end

-- A key code has one `keypress' and some optional modifiers.
-- For comparisons to work, keycodes are immutable atoms.
local keycode_mt = {
  -- Output the write syntax for this keycode (e.g. C-M-<f1>).
  __tostring = function (self)
    return mapkey (codetoname, self, {C = "C-", M = "M-"})
  end,

  -- Normalise modifier lookups to uppercase, sans `-' suffix.
  --   hasmodifier = keycode.META or keycode["c"]
  __index = function (self, mod)
    mod = string.upper (string.sub (mod, 1, 1))
    return rawget (self, mod)
  end,

  -- Return the immutable atom for this keycode with modifier added.
  --   ctrlkey = "\\C-" + key
  __add = function (self, mod)
    if type (self) == "string" then mod, self = self, mod end
    mod = string.upper (string.sub (mod, 2, 2))
    if self[mod] then return self end
    return keycode ("\\" .. mod .. "-" .. toreadsyntax (self))
  end,

  -- Return the immutable atom for this keycode with modifier removed.
  --   withoutmeta = key - "\\M-"
  __sub = function (self, mod)
    if type (self) == "string" then mod, self = self, mod end
    mod = string.upper (string.sub (mod, 2, 2))
    local keystr = string.gsub (toreadsyntax (self), "\\" .. mod .. "%-", "")
    return keycode (keystr)
  end,
}

local equivs = {
  ["\\NEXT"] = "\\PAGEDOWN",
  ["\\PRIOR"] = "\\PAGEUP",
  ["\\e"] = "\\ESC",
  ["\\r"] = "\\RET", -- FIXME: Kludge to make keystrings work in both Emacs and Zile.
  ["\\t"] = "\\TAB",
  ["\t"] = "\\TAB",
  [" "] = "\\SPC",
}

-- Extract a prefix of a key string.
local function strtokey (tail)
  if tail == "\\" then
    return "\\", ""
  end

  local head, real_key
  for match, equiv in pairs (equivs) do
    if match == tail:sub (1, #match) then
      head, real_key = match, equiv
      break
    end
  end
  if not head then
    for match in pairs (keynametocode) do
      if match == tail:sub (1, #match) then
        head, real_key = match, match
        break
      end
    end
  end
  if head then
    return real_key, tail:sub (#head + 1)
  end

  return "", nil
end

local function string_to_keycode (chord)
  local key, tail = setmetatable ({}, keycode_mt), chord

  local fragment
  repeat
    fragment, tail = strtokey (tail)
    if fragment == nil then return nil end

    if fragment == "\\C-" then
      key.CTRL = true
    elseif fragment == "\\M-" then
      key.META = true
    elseif fragment == "\\" then
      key.key = keynametocode["\\\\"]
    else
      key.key = keynametocode[fragment]
    end
  until fragment ~= "\\C-" and fragment ~= "\\M-"

  return key, fragment
end

memoized_keycode = memoize (string_to_keycode)

-- Convert a single keychord string to its key code.
-- First normalize the keycode, then call a memoized version so we get
-- an identical table, which can be compared, on each call with the
-- same chord.
function keycode (chord)
  local key, fragment = string_to_keycode (chord)

  -- Normalise modifiers so that \\C-\\M-r and \\M-\\C-r are the same
  -- atom.
  local k = (key.CTRL and "\\C-" or "") .. (key.META and "\\M-" or "") .. fragment
  return memoized_keycode (k)
end

-- Convert a list of keychord strings to a set of key codes.
-- Create a new stdlib set of keycode objects.
-- A fast way to check for a group of keys:
--   if keyset {"x", "y", "z"}:member (key) then ... end
function keyset (l)
  return set.new (list.map (keycode, l))
end

-- Iterator over a key sequence string, returning the next key chord on
-- each iteration.
local function keychords (s)
  local tail = s

  local function strtochord (tail)
    local head, fragment = ""

    repeat
      fragment, tail = strtokey (tail)
      if fragment == nil then return nil end
      head = head .. fragment
    until fragment ~= "\\C-" and fragment ~= "\\M-"

    return head, tail
  end

  return function ()
    while tail ~= "" do
      local head
      head, tail = strtochord (tail)
      return head
    end
  end
end

-- Convert a key sequence string into a key code sequence, or nil if
-- it can't be converted.
function keystrtovec (s)
  local keys = setmetatable ({}, {
    __tostring = function (self)
                   return table.concat (list.map (tostring, self), " ")
                 end
  })

  for chord in keychords (s) do
    if chord == nil then
      return nil
    end
    table.insert (keys, keycode (chord))
  end

  return keys
end
