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
-- along with this program.  If not, see <htt://www.gnu.org/licenses/>.

--[[--
 Efficient string buffers.

 An MutableString is a fast array of bytes, and methods to query and
 manipulate it.

 Create a new MutableString with:

     > MutableString = require "zile.MutableString"
     > =MutableString "the content"
     the content

 All the indexes passed to methods use 1-based counting.

 @classmod zile.MutableString
]]


local alien  = require "alien"
local Object = require "std.object"

local allocation_chunk_size = 16


--- Look for the first occurrence of `s` starting at `from`.
-- @function find
-- @string s string to search for
-- @int from index to start search
local find

local have_memmem = pcall (loadstring [[
  alien.default.memmem:types ("pointer", "pointer", "size_t", "pointer", "size_t")
]])

if have_memmem then

  -- Use the faster memmem implementation if libc provides it.
  function find (self, s, from)
    local n = #self - (from - 1)
    if n > 0 and n <= #self then
      local b, needle = self.buf.buffer, alien.buffer (s)
      local next =
        alien.default.memmem (b:topointer (from), n, needle:topointer (), #s)
      return next and b:tooffset (next) or nil
    end
  end

else

  alien.default.memchr:types ("pointer", "pointer", "int", "size_t")

  -- Use memchr, and then check array members manually if necessary.
  function find (self, s, from) -- FIXME for #s > 1 (crlf)
    local n = #self - (from - 1)
    if n > 0 and n <= #self then -- skip if from if out-of-bounds
      local b, c = self.buf.buffer, string.byte (s)
      local next = alien.default.memchr (b:topointer (from), c, n)
      return next and b:tooffset (next) or nil
    end
  end

end


--- Create an unused `n` byte _hole_.
-- Enlarge the array if necessary and move everything starting at
-- `from`, `n` bytes to the right.
-- @function insert
-- @int from index of the first byte of the new _hole_
-- @int n number of empty bytes to insert
local function insert (self, from, n)
  assert (from <= #self + 1)
  self:set_len (#self + n)
  self:move (from + n, from, #self + 1 - (from + n))
  self:set (from, '\0', n)
end


--- Move `n` bytes from `from` to `to`.  The two byte strings may
-- overlap.
-- @int to start of destination within this MutableString
-- @int from start of source bytes within the MutableString
-- @int n number of bytes to move
local function move (self, to, from, n)
  assert (math.max (from, to) + n <= #self + 1)
  alien.memmove (self.buf.buffer:topointer (to), self.buf.buffer:topointer (from), n)
end


--- Remove `n` bytes starting at `from`.
-- There is no _hole_ afterwards; the following bytes are moved up to
-- fill it.  The total size of the MutableString may be reduced.
-- @function remove
-- @int from index of first byte to remove
-- @int n number of bytes to remove
local function remove (self, from, n)
  assert (from + n <= #self + 1)
  self:move (from + n, from, n)
  self:set_len (#self - n)
end


--- Overwrite bytes starting at `from` with bytes from `rep`.
-- @int from index of first byte to replace
-- @string rep replacement string
local function replace (self, from, rep)
  assert (from + #rep <= #self + 1)
  alien.memmove (self.buf.buffer:topointer (from), rep, #rep)
end


--- Look for the **last** occurrence of `s` before `from`.
-- @function rfind
-- @string s string to search for
-- @int to largest index to search
local rfind

local have_memrchr = pcall (loadstring [[
  alien.default.memrchr:types ("pointer", "pointer", "int", "size_t")
]])

if have_memrchr then

  -- Use the faster memrchr implementation if libc provides it.
  function rfind (self, s, from) -- FIXME for #s > 1 (crlf)
    local n = from - 1
    if n > 0 and n <= #self then -- skip if out-of-bounds
      local b, c = self.buf.buffer, string.byte (s)
      local prev = alien.default.memrchr (b:topointer (), c, n)
      return prev and b:tooffset (prev) or nil
    end
  end

else

  -- Check array members manually if necessary.
  function rfind (self, s, to) -- FIXME for #s > 1 (crlf)
    local b, c = self.buf, string.byte (s)
    for i = to - 1, 1, -1 do
      if b[i] == c then return i end
    end
  end

end


--- Set `n` bytes starting at `from` to the first character of `c`.
-- @int from index of first byte to set
-- @string c a one character string
-- @int n number of bytes to set
local function set (self, from, c, n)
  assert (from + n <= #self + 1)
  alien.memset (self.buf.buffer:topointer (from), c:byte (), n)
end


--- Change the number of bytes allocated to be at least `n`.
-- @int n the number of bytes required
local function set_len (self, n)
  if n > self.buf.length or n < self.buf.length / 2 then
    self.buf:realloc (n + allocation_chunk_size)
  end
  self.length = n
end


--- Return a copy of a substring of this MutableString.
-- @int from the index of the first element to copy.
-- @int to the index of the last element to copy.
-- @treturn string a new Lua string
local function sub (self, from, to)
  return tostring (self):sub (from, to) -- FIXME
end


------
-- An efficient string buffer object.
-- @table Astr
-- @int length number of bytes currently allocated
-- @tfield alien.array buf a block of mutable memory
return Object {
  _type      = "MutableString",

  -- Instantiate a newly cloned MutableString.
  _init = function (self, s)
    self.buf = alien.array ("char", #s, alien.buffer (s))
    self.length = #s
    return self
  end,


  --- Return the string contents of this MutableString.
  -- @function __tostring
  __tostring = function (self)
    return self.buf.buffer:tostring (#self)
  end,


  --- Return the number of bytes in this MutableString.
  -- @function __len
  __len = function (self)
    return self.length
  end,


  --- @export
  __index    = {
    find     = find,
    insert   = insert,
    move     = move,
    replace  = replace,
    rfind    = rfind,
    set      = set,
    set_len  = set_len,
    sub      = sub,
  },
}
