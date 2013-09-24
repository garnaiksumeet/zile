-- Zi-specific library functions
--
-- Copyright (c) 2006-2010, 2012 Free Software Foundation, Inc.
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


-- Recase str according to newcase.
function recase (s, newcase)
  local bs = ""
  local i, len

  if newcase == "capitalized" or newcase == "upper" then
    bs = bs .. string.upper (s[1])
  else
    bs = bs .. string.lower (s[1])
  end

  for i = 2, #s do
    bs = bs .. (newcase == "upper" and string.upper or string.lower) (s[i])
  end

  return bs
end

-- Turn texinfo markup into plain text
function texi (s)
  s = string.gsub (s, "@i{([^}]+)}", function (s) return string.upper (s) end)
  s = string.gsub (s, "@kbd{([^}]+)}", "%1")
  s = string.gsub (s, "@samp{([^}]+)}", "%1")
  s = string.gsub (s, "@itemize%s[^\n]*\n", "")
  s = string.gsub (s, "@end%s[^\n]*\n", "")
  return s
end


-- Basic stack operations
stack = {}

local metatable = {}

-- Pops and Pushes must balance, so instead of pushing `nil', which
-- already means "no entry" and cause the matching pop to remove an
-- unmatched value beneath the "missing" nil, use stack.empty:
stack.empty = math.huge

-- Return a new stack, optionally initialised with elements from t.
function stack.new (t)
  return setmetatable (t or {}, metatable)
end

-- Push v on top of a stack, creating an empty cell when v is nil.
function stack:push (v)
  table.insert (self, v or stack.empty)
  return self[#self]
end

-- Pop and return the top of a stack, or nil for empty cells.
function stack:pop ()
  local v = table.remove (self)
  return v ~= stack.empty and v or nil
end

-- Return the value from the top of a stack, ignoring empty cells.
function stack:top ()
  if #self < 1 then return nil end
  local n = 0
  while n + 1 < #self and self[#self - n] == stack.empty do
    n = n + 1
  end
  assert (n < #self)
  local v = self[#self - n]
  return v ~= stack.empty and v or nil
end

-- Metamethods for stack tables
-- stack:method ()
metatable.__index = stack
