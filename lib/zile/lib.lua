-- Zile-specific library functions
--
-- Copyright (c) 2006-2010, 2012-2014 Free Software Foundation, Inc.
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


-- Return true if x is a function, or is a Symbol with a __call metamethod.
function iscallable (x)
  if type (x) == "function" then return true end
  local mt = getmetatable (x)
  return mt and mt.__call and mt._type == "Symbol"
end

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
