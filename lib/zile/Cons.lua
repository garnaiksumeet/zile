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
 Cons cell.

 A cons cell contains two elements, `car` and `cdr` (the _contents-address-
 register_, and _contents-decrement-register_) used to make linked lists
 and _S-Expressions_, among others, in Lisp-like languages.

 Create a new cell with:

      > Cons = require "zile.Cons"
      > =Cons ("e1", "e2")
      {car=e1,cdr=e2}

 Cons lists behave as expected:

      > head = Cons ("e1", Cons ("e2", Cons ("e3")))
      > =head
      {car=e1,cdr={car=e2,cdr={car=e3}}}

 Methods can be chained:

      > =head:reverse():concat(",")
      e3,e2,e1

 Object methods can also be called as "class methods" with:

      > =head:nth (2)
      e2
      > =Cons.nth (head, 2)
      e2

 @classmod zile.Cons
]]


local Cons -- forward declaration


local methods = {
  --- Return the nth element of a cons list.
  -- @function nth
  -- @tparam number n 1-based index into the list
  -- @return car element of the nth cell in the cons list
  nth = function (self, n)
    if type (n) ~= "number" or n < 1 or self == nil then
      return nil
    elseif n == 1 then
      return self.car
    end

    return self.nth (self.cdr, n - 1)
  end,


  --- Concantenate the value field of each car element in a list.
  -- Equivalent to table.concat for lists of cons cells.
  -- @function concat
  -- @tparam[opt=""] string delim delimiter to place between elements
  -- @treturn string `delim` delimited concatenation of the list.
  concat = function (self, delim)
    delim = delim or ""
    local s = tostring (self.car.value or self.car)
    if self.cdr == nil then return s end
    return s .. delim .. self.concat (self.cdr, delim)
  end,


  --- Return a non-destructively reversed cons list.
  -- @function reverse
  -- @treturn Cons a new list with elements in reverse order
  reverse = function (self)
    local r = nil
    while self ~= nil do
      r = Cons (self.car, r)
      self = self.cdr
    end
    return r
  end,
}


function Cons (car, cdr)
  return setmetatable ({car = car, cdr = cdr}, {__index = methods})
end


--- Return a new Cons cell with supplied car and cdr.
-- @function __call
-- @param car first element
-- @param cdr last element
-- @treturn Cons a new cell containing those elements
return setmetatable (methods, {
  __call = function (_, ...)
    return Cons (...)
  end,
})
