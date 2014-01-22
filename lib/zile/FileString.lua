-- Copyright (c) 2011-2014 Free Software Foundation, Inc.
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

--[[--
 Mutable strings with line-ending encodings

 All the indexes passed to methods use 1-based counting.

 @classmod zile.FileString
]]

local MutableString = require "zile.MutableString"
local Object        = require "std.object"

-- Formats of end-of-line
coding_eol_lf = "\n"
coding_eol_crlf = "\r\n"
coding_eol_cr = "\r"

-- Maximum number of EOLs to check before deciding eol type arbitrarily.
local max_eol_check_count = 3


------
-- An line-ending encoding string buffer object.
-- @table FileString
-- @param s a MutableString
-- @string eol line ending encoding
local FileString


-- documentation below to stop LDoc complaining there are no docs!!
local function bytes (self)
  return #self.s
end
------
-- Number of bytes in the string.
-- @function bytes
-- @treturn int byte length of string


--- Concatenate another string.
-- @string src additional string
-- @treturn FileString modified concatenated object
local function cat (self, src)
  local oldlen = #self.s
  self.s:insert (oldlen + 1, src:len (self.eol))
  return self:replace (oldlen + 1, src)
end


--- Position of first end-of-line following `o`.
-- @int o start position
-- @treturn int position of first following end-of-line
local function end_of_line (self, o)
  local next = self.find (self.s, self.eol, o)
  return next or #self.s + 1
end


--- Create an unused `n` byte _hole_.
-- Enlarge the array if necessary and move everything starting at
-- `from`, `n` bytes to the right.
-- @function insert
-- @int from index of the first byte of the new _hole_
-- @int n number of empty bytes to insert
local function insert (self, from, n)
  self.s:insert (from, n)
end


--- Encoded length.
-- @string eol_type line-end string
-- @treturn int length of string using `eol_type` line endings
local function len (self, eol_type) -- FIXME in Lua 5.2 use __len metamethod
  return self:bytes () + self:lines () * (#eol_type - #self.eol)
end


--- Number of lines.
-- @treturn int number of lines.
local function lines (self)
  local lines, next = -1, 1
  repeat
    next = self:next_line (next)
    lines = lines + 1
  until not next
  return lines
end


--- Move `n` bytes from `from` to `to`.  The two byte strings may
-- overlap.
-- @int to start of destination within this MutableString
-- @int from start of source bytes within the MutableString
-- @int n number of bytes to move
local function move (self, to, from, n)
  self.s:move (to, from, n)
end

  
--- Position of start of immediately following line.
-- @int o start position
-- @treturn int position of start of next line
local function next_line (self, o)
  local eo = self:end_of_line (o)
  return eo <= #self.s and eo + #self.eol or nil
end


--- Position of start of immediately preceding line.
-- @int o start position
-- @treturn int position of start of previous line
local function prev_line (self, o)
  local so = self:start_of_line (o)
  return so ~= 1 and self:start_of_line (so - #self.eol) or nil
end


--- Remove `n` bytes starting at `from`.
-- There is no _hole_ afterwards; the following bytes are moved up to
-- fill it.  The total size of the MutableString may be reduced.
-- @function remove
-- @int from index of first byte to remove
-- @int n number of bytes to remove
local function remove (self, from, n)
  self.s:remove (from, n)
end

  
--- Overwrite bytes starting at `from` with bytes from `rep`.
-- @int from index of first byte to replace
-- @string src replacement string
local function replace (self, from, src)
  local s = 1
  local len = #src.s
  while len > 0 do
    local next = src.s:find (src.eol, s + #src.eol + 1)
    local line_len = next and next - s or len
    self.s:replace (from, src.s:sub (s, s + line_len))
    from = from + line_len
    len = len - line_len
    s = next
    if len > 0 then
      self.s:replace (from, self.eol)
      s = s + #src.eol
      len = len - #src.eol
      from = from + #self.eol
    end
  end
  return self
end


--- Position of first end-of-line preceding `o`.
-- @int o start position
-- @treturn int position of first preceding end-of-line
local function start_of_line (self, o)
  local prev = self.rfind (self.s, self.eol, o)
  return prev and prev + #self.eol or 1
end


--- Set `n` bytes starting at `from` to the first character of `c`.
-- @int from index of first byte to set
-- @string c a one character string
-- @int n number of bytes to set
local function set (self, from, c, n)
  self.s:set (from, c, n)
end

  
--- Return a copy of a substring of this MutableString.
-- @int from the index of the first element to copy.
-- @int[opt=end-of-string] to the index of the last element to copy.
-- @treturn string a new Lua string
local function sub (self, from, to)
  return self.s:sub (from, to)
end


--- @export
local methods = {
  bytes         = bytes,
  cat           = cat,
  end_of_line   = end_of_line,
  insert        = insert,
  len           = len,
  lines         = lines,
  move          = move,
  next_line     = next_line,
  prev_line     = prev_line,
  remove        = remove,
  replace       = replace,
  start_of_line = start_of_line,
  set           = set,
  sub           = sub,
}

  
FileString = Object {
  _type = "FileString",


  --- Instantiate a newly cloned object.
  -- @function __call
  -- @string s a Lua string
  -- @string eol line-ending encoding
  -- @treturn FileString a new FileString object
  _init = function (self, s, eol)
    if eol then -- if eol supplied, use it
      self.eol = eol
    else -- otherwise, guess
      local first_eol = true
      local total_eols = 0
      self.eol = coding_eol_lf
      local i = 1
      while i <= #s and total_eols < max_eol_check_count do
        local c = s[i]
        if c == '\n' or c == '\r' then
          local this_eol_type
          total_eols = total_eols + 1
          if c == '\n' then
            this_eol_type = coding_eol_lf
          elseif i == #s or s[i + 1] ~= '\n' then
            this_eol_type = coding_eol_cr
          else
            this_eol_type = coding_eol_crlf
            i = i + 1
          end

          if first_eol then
            -- This is the first end-of-line.
            self.eol = this_eol_type
            first_eol = false
          elseif self.eol ~= this_eol_type then
            -- This EOL is different from the last; arbitrarily choose LF.
            self.eol = coding_eol_lf
            break
          end
        end
        i = i + 1
      end
    end

    if type (s) == "string" then
      self.s = MutableString (s)
      if #self.eol == 1 then
        -- Use faster search functions for single-char eols.
        self.find, self.rfind = MutableString.chr, MutableString.rchr
      else
        self.find, self.rfind = MutableString.find, MutableString.rfind
      end
    else
      self.s = s
      -- Non-MutableStrings have to provide their own find and rfind
      -- functions.
      self.find, self.rfind = self.s.find, self.s.rfind
    end
    return self
  end,


  --- Return the string contents.
  -- @function __tostring
  __tostring = function (self)
    return tostring (self.s)
  end,


  --- Return the `n`th character.
  -- @function __index
  -- @int n 1-based index
  -- @treturn string the character at index `n`
  __index = function (self, n)
    return case (type (n), {
      -- Do character lookup with an integer...
      number   = function () return self.s[n] end,

      -- ...otherwise dispatch to method table.
      function () return methods[n] end,
    })
  end,
}

return FileString
