-- Key bindings and extended commands
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

local eval = require "zmacs.eval"

-- gather_bindings_state:
-- {
--   f: symbol to match
--   bindings: bindings
-- }

local function gather_bindings (key, p, g)
  if p == g.f then table.insert (g.bindings, key) end
end


--- Find key bindings to a command.
-- @string name name of a command
-- @treturn table a table of key bindings for `name`, or nil.
local function where_is (name)
  if name and eval.intern_soft (name) then
    local g = { f = eval.intern_soft (name), bindings = {} }
    walk_bindings (root_bindings, gather_bindings, g)
    return g.bindings
  end
end

return {
  where_is = where_is,
}
