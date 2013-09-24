-- Efficient string buffers
--
-- Copyright (c) 2011-2013 Free Software Foundation, Inc.
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

  find = function (self, s, from)
    return tostring (self):find (s, from) -- FIXME
  end,

  rfind = function (self, s, from)
    return find_substr (tostring (self), s, 1, from - 1, false, true, true, false, false) -- FIXME
  end
}
