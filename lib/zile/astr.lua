-- Efficient string buffers
--
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

local Object = require "std.object"


local allocation_chunk_size = 16
AStr = Object {
  _init = function (self, s)
    self.buf = alien.array ("char", #s, alien.buffer (s))
    self.length = #s
    return self
  end,

  __tostring = function (self)
    return self.buf.buffer:tostring (#self)
  end,

  __len = function (self)
    return self.length
  end,

  sub = function (self, from, to)
    return tostring (self):sub (from, to) -- FIXME
  end,

  set_len = function (self, n)
    if n > self.buf.length or n < self.buf.length / 2 then
      self.buf:realloc (n + allocation_chunk_size)
    end
    self.length = n
  end,

  move = function (self, to, from, n)
    assert (math.max (from, to) + n <= #self + 1)
    alien.memmove (self.buf.buffer:topointer (to), self.buf.buffer:topointer (from), n)
  end,

  set = function (self, from, c, n)
    assert (from + n <= #self + 1)
    alien.memset (self.buf.buffer:topointer (from), c:byte (), n)
  end,

  remove = function (self, from, n)
    assert (from + n <= #self + 1)
    self:move (from + n, from, n)
    self:set_len (#self - n)
  end,

  insert = function (self, from, n)
    assert (from <= #self + 1)
    self:set_len (#self + n)
    self:move (from + n, from, #self + 1 - (from + n))
    self:set (from, '\0', n)
  end,

  replace = function (self, from, rep)
    assert (from + #rep <= #self + 1)
    alien.memmove (self.buf.buffer:topointer (from), rep, #rep)
  end,

  find = function (self, s, from) -- FIXME for #s > 1 (crlf)
    local n = #self - (from - 1)
    if n > 0 and n <= #self then -- skip if from if out-of-bounds
      local b, c = self.buf.buffer, string.byte (s)
      local next = alien.default.memchr (b:topointer (from), c, n)
      return next and b:tooffset (next) or nil
    end
  end,

  rfind = function (self, s, from) -- FIXME for #s > 1 (crlf)
    local b, c = self.buf, string.byte (s)
    for i = from - 1, 1, -1 do
      if b[i] == c then return i end
    end
  end,
}

alien.default.memchr:types ("pointer", "pointer", "int", "size_t")

local have_memrchr, rfind = pcall (loadstring [[
  alien.default.memrchr:types ("pointer", "pointer", "int", "size_t")

  return function (self, s, from) -- FIXME for #s > 1 (crlf)
    local n = from - 1
    if n > 0 and n <= #self then -- skip if out-of-bounds
      local b, c = self.buf.buffer, string.byte (s)
      local prev = alien.default.memrchr (b:topointer (), c, n)
      return prev and b:tooffset (prev) or nil
    end
  end
]])

-- Use the faster memrchr implementation if libc provides it.
if have_memrchr then AStr.rfind = rfind end
