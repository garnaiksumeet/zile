-- Copyright (c) 2013-2014 Free Software Foundation, Inc.
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

------
-- Cons cell.
-- @table cons
-- @field car content address register
-- @field cdr content decrement register


--- Concantenate the value field of each car element in a list.
-- Equivalent to table.concat for lists of cons cells.
-- @tparam[opt=""] string delim delimiter to place between elements
-- @treturn string `delim` delimited concatenation of the list.
local function concat (self, delim)
  delim = delim or ""
  local s = tostring (self.car.value or self.car)
  if self.cdr == nil then return s end
  return s .. delim .. self.concat (self.cdr, delim)
end


--- Return a new Cons list with elements that match `predicate`.
-- @func predicate a one parameter function that returns a boolean
-- @treturn cons list of elements where `predicate` returned `true`
local function filter (self, predicate)
  if self == nil then return nil end

  local car = self.car.value or self.car
  if predicate (car) then
    return Cons (car, self.filter (self.cdr, predicate))
  else
    return self.filter (self.cdr, predicate)
  end
end


--- Apply a function to the value field of each car element in a list.
-- @func func a one parameter function that returns a string
-- @tparam[opt=""] string delim delimiter to place between elements
-- @treturn string `delim` delimited concatenation of the list.
local function mapconcat (self, func, delim)
  delim = delim or ""
  local s = tostring (func (self.car.value or self.car))
  if self.cdr == nil then return s end
  return s .. delim .. self.mapconcat (self.cdr, func, delim)
end


--- Return the nth element of a cons list.
-- @tparam number n 1-based index into the list
-- @return car element of the nth cell in the cons list
local function nth (self, n)
  if type (n) ~= "number" or n < 1 or self == nil then
    return nil
  elseif n == 1 then
    return self.car
  end

  return self.nth (self.cdr, n - 1)
end


--- Return a non-destructively reversed cons list.
-- @treturn cons a new list with elements in reverse order
local function reverse (self)
  local r = nil
  while self ~= nil do
    r = Cons (self.car, r)
    self = self.cdr
  end
  return r
end


--- Is `x` a Cons object?
-- @param x a Lua object
-- @return `true` if `x` is a Cons object, or else `false`
local function consp (x)
  return (getmetatable (x) or {})._type == "Cons"
end



--- Return a short string representation of a cons list.
-- @tparam cons cons a cons cell, or cons list
-- @treturn string a short string representation of `cons`
local function stringify (cons)
  if not consp (cons) then return tostring (cons) end

  local s = ""
  if cons.car ~= nil then s = tostring (cons.car) end

  if consp (cons.cdr) then
    s = s .. " " .. stringify (cons.cdr)
  elseif cons.cdr ~= nil then
    s = s .. " . " .. stringify (cons.cdr)
  end
  return s
end


-- Shared metatable for Cons objects.
-- @table metatable
-- @string _type used by consp to recognise Cons objects
-- @tfield table __index a table of object methods
-- @func __tostring stringification metamethod
local metatable = {
  _type = "Cons",

  -- Object methods:
  __index = {
    concat    = concat,
    filter    = filter,
    mapconcat = mapconcat,
    nth       = nth,
    reverse   = reverse,
  },

  __tostring = function (self)
    return "(" .. stringify (self) .. ")"
  end,
}


--- Return a new cons cell with supplied car and cdr.
-- @local
-- @param car first element
-- @param cdr last element
-- @treturn cons a new cell containing those elements
function Cons (car, cdr)
  return setmetatable ({car = car, cdr = cdr}, metatable)
end


--- @export
-- Module functions:
local functions = {
  concat    = concat,
  consp     = consp,
  filter    = filter,
  mapconcat = mapconcat,
  nth       = nth,
  reverse   = reverse,
}


return setmetatable (functions, {
  --- Return a new Cons cell with supplied car and cdr.
  -- @function __call
  -- @param car first element
  -- @param cdr last element
  -- @treturn cons a new cell containing those elements
  __call = function (_, ...)
    return Cons (...)
  end,
})
