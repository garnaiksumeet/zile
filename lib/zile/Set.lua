-- Copyright (c) 2013 Free Software Foundation, Inc.
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
 Set container.

 A set is a table who's keys are the elements, all with value `true`

 Create a new sets with:

      new = Set {"e1", "e2", ... "en"}

 Add new elements with:

      union = new + {"f1", "f2", ... "fn"}

 Test membership with:

      new["e2"] => true
      new["x"] => nil

 @classmod zile.Set
]]

local Set -- forward declaration


local functions = {
  --- Find the union of two sets.
  -- @static
  -- @tparam Set set1 a set
  -- @tparam table|Set set2 another set, or table
  -- @treturn Set union of `set1` and `set2`
  union = function (set1, set2)
    local r = Set ()
    for k in pairs (set1) do rawset (r, k, true) end
    for k in pairs (set2) do rawset (r, k, true) end
    return r
  end,
}


local metamethods = {
  --- Union operator.
  --     union = set + table
  --  @function __add
  --  @tparam Set self set
  --  @tparam table|Set table another set or table
  --  @treturn Set union of those sets
  __add = functions.union,


  -- Object methods:
  --     u = s:union (t)
  __index = functions,
}


Set = setmetatable (functions, {
  --- Return a new Set containing values from t.
  -- @function __call
  -- @static
  -- @tparam table t a list of elements
  -- @treturn Set a new set containing those elements
  __call = function (self, t)
    local r = setmetatable ({}, metamethods)
    if t ~= nil then
      for _, v in pairs (t) do rawset (r, v, true) end
    end
    return r
  end,
})


return Set
