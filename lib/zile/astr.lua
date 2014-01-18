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


alien.default.memchr:types ("pointer", "pointer", "int", "size_t")

local function memchr (buf, ch, o)
  local b = buf.buffer
  local next = alien.default.memchr (
    b:topointer (o), string.byte (ch), #b - (o - 1))
  return next and b:tooffset (next) or nil
end

local function memrchr (buf, ch, o)
  local c = string.byte (ch)
  for i = o, 1, -1 do
    if buf[i] == c then return i end
  end
end

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

  find = function (self, ch, from)
    return memchr (self.buf, ch, from)
  end,

  rfind = function (self, ch, from)
    return memrchr (self.buf, ch, from - 1)
  end
}
