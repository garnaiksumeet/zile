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
local table  = require "std.table"

local calloc, cstring, libc, memmove, memset =
  alien.array, alien.buffer, alien.default, alien.memmove, alien.memset

local clone, merge = table.clone, table.merge


local utils = require "zile.lib"

-- local case = utils.case -- FIXME uncomment when zile.lib returns a table


local MutableString  -- forward declaration

local allocation_chunk_size = 16


libc.memchr:types ("pointer", "pointer", "int", "size_t")


--- Lock for the first occurrence of `ch` starting at `from`.
-- @string ch a one character string to search for
-- @int from index to start search
local function chr (self, ch, from)
  local n = #self - (from - 1)
  if n > 0 and n <= #self then -- skip if from if out-of-bounds
    local b, c = self.buf.buffer, string.byte (ch)
    local next = libc.memchr (b:topointer (from), c, n)
    return next and b:tooffset (next) or nil
  end
end


--- Look for the first occurrence of `s` starting at `from`.
-- @function find
-- @string s string to search for
-- @int from index to start search
local find

local have_memmem = pcall (loadstring [[
  libc.memmem:types ("pointer", "pointer", "size_t", "pointer", "size_t")
]])

if have_memmem then

  -- Use the faster memmem implementation if libc provides it.
  function find (self, s, from)
    local n = #self - (from - 1)
    if n > 0 and n <= #self then
      local b, needle = self.buf.buffer, cstring (s)
      local next =
        libc.memmem (b:topointer (from), n, needle:topointer (), #s)
      return next and b:tooffset (next) or nil
    end
  end

else

  -- Use chr, and then check array members manually if necessary.
  function find (self, s, from)
    local b, len = self.buf.buffer, #s
    while from and from + len <= #self do
      from = chr (self, s, from)
      if from and b:tostring (len, from) == s then return from end
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
  memmove (self:topointer (to), self:topointer (from), n)
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
  memmove (self:topointer (from), rep, #rep)
end


--- Look for the **last** occurrence of `ch` before `to`.
-- @function rchr
-- @string ch a one character string to search for
-- @int to largest index to search
local rchr

local have_memrchr = pcall (loadstring [[
  libc.memrchr:types ("pointer", "pointer", "int", "size_t")
]])

if have_memrchr then

  -- Use the faster memrchr implementation if libc provides it.
  function rchr (self, s, from)
    local n = from - 1
    if n > 0 and n <= #self then -- skip if out-of-bounds
      local b, c = self.buf.buffer, string.byte (s)
      local prev = libc.memrchr (b:topointer (), c, n)
      return prev and b:tooffset (prev) or nil
    end
  end

else

  -- Check array members manually if necessary.
  function rchr (self, s, to)
    local b, c = self.buf, string.byte (s)
    for i = to - 1, 1, -1 do
      if b[i] == c then return i end
    end
  end

end


--- Look for the **last** occurrence of `s` before `to`.
-- @function rfind
-- @string s string to search for
-- @int to largest index to search
local function rfind (self, s, to)
  local b, len = self.buf.buffer, #s
  to = to - #s + 1
  while to and to > 0 do
    to = rchr (self, s, to)
    if to and b:tostring (len, to) == s then return to end
  end
end


--- Set `n` bytes starting at `from` to the first character of `c`.
-- @int from index of first byte to set
-- @string c a one character string
-- @int n number of bytes to set
local function set (self, from, c, n)
  assert (from + n <= #self + 1)
  memset (self:topointer (from), c:byte (), n)
end


--- Change the number of bytes allocated to be at least `n`.
-- @int n the number of bytes required
local function set_len (self, n)
  local a = self.buf
  if n > a.length or n < a.length / 2 then
    a:realloc (n + allocation_chunk_size)
  end
  self.length = n
end


--- Return a copy of a substring of this MutableString.
-- @int from the index of the first element to copy.
-- @int[opt=end-of-string] to the index of the last element to copy.
-- @treturn string a new Lua string
local function sub (self, from, to)
  to = to or self.length
  return tostring (self):sub (from, to) -- FIXME
end


--- Convert a Lua offset to a C pointer into this MutableString.
-- @function topointer
-- @int offset 1-based offset from start of this MutableString.
-- @return a pointer suitable for passing to C
local function topointer (self, offset)
  return self.buf.buffer:topointer (offset)
end


--- @export
local _functions = {
  chr     = chr,
  find    = find,
  insert  = insert,
  move    = move,
  rchr    = rchr,
  replace = replace,
  rfind   = rfind,
  set     = set,
  set_len = set_len,
  sub     = sub,
}


-- Object methods include all module functions, plus `topointer`
local methods = merge (clone (_functions), {
  topointer = topointer,
})


------
-- An efficient string buffer object.
-- @table MutableString
-- @int length number of bytes currently allocated
-- @tfield alien.array buf a block of mutable memory
MutableString = Object {
  _type      = "MutableString",


  -- Module functions.
  _functions = _functions,


  --- Instantiate a newly cloned MutableString.
  -- @function __call
  -- @param init either a string or a MutableString to copy, or the
  --   number of bytes to allocate for a number
  -- @int[opt] len the number of bytes to copy if `init` is a
  --   MutableString
  -- @treturn MutableString a new MutableString object
  _init = function (self, init, len)
    case (type (init),
    {
      string   = function ()
                   self.buf    = calloc ("char", #init, cstring (init))
                   self.length = #init
		 end,
      number   = function ()
                   self.buf    = calloc ("char", math.max (init, 1))
                   self.length = init
		 end,
      userdata = function ()
                   self.buf    = calloc ("char", len, cstring (init))
                   self.length = len
		 end,
      --[[else]] function ()
                   self.buf    = calloc ("char", init)
                   self.length = #init
		 end,
    })
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


  --- Return the `n`th character in this MutableString.
  -- @function __index
  -- @int n 1-based index
  -- @treturn string the character at index `n`
  __index = function (self, n)
    return case (type (n), {
      -- Do character lookup with an integer...
      number   = function () return self.buf[n] end,

      -- ...otherwise dispatch to method table.
      function () return methods[n] end,
    })
  end,
}

return MutableString
