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
 ZLisp Symbol.

 A symbol has a name, a value and a property list. It is usually stored
 in the global symbol table `obarray`, in which it is _interned_.  It's
 not necessary to intern a symbol using it's own name, though it is
 certainly easier to understand what's going on if you do.

 Symbols can also be interned into some other symbol table, by passing
 a different Lua table reference to the appropropriate parameter of the
 functions in this module.

 Create a new uninterned symbol with:

     > Symbol = require "zile.Symbol"
     > sym = Symbol.make_symbol ("answer", 42)

 Access the name and value with the dot operator:

     > =sym.name
     answer
     > =sym.value
     42

 Symbols also have a property list; an association of property names
 and values.  Use the `[]` operator to access the property list.

     > =sym["prop-name"]
     nil
     > sym["prop-name"] = "some value"
     > =sym["prop-name"]
     some value

 Alternatively, create an interned symbol with:

     > bol = Symbol ("question")
     > bol.value = "6 times 7"

 And retrieve it with:

     > =(bol == Symbol.intern_soft "question")
     true

 There is no way to access the contents of the default symbol table,
 except to use the @{mapatoms} function.

 @classmod zile.Symbol
]]


--- ZLisp symbols.
-- A mapping of symbol-names to symbol-values.
-- @table obarray
local obarray = {}


--- Make a new, uninterned, symbol.
-- @string name symbol name
-- @param[opt=nil] value value to store in new symbol
-- @tparam[opt={}] table plist property list for new symbol
-- @treturn zile.Symbol newly initialised symbol
local function make_symbol (name, value, plist)
  local symbol = {
    name  = name,
    value = value,
    plist = plist or {},
  }

  return setmetatable (symbol, {
    __index    = symbol.plist,
    __newindex = function (self, propname, value)
	           if propname == 'name' or propname == 'value' then
		     return rawset (self, propname, value)
		   end
                   return rawset (self.plist, propname, value)
		 end,
    __tostring = function (self) return self.name end,
  })
end


--- Make a new symbol and intern to `symtab`.
-- Overwrites any previous definition of symbol `name` in `symtab`.
-- @string name symbol name
-- @param[opt=nil] value value to store in new symbol
-- @tparam[opt=obarray] table symtab symbol table into which new symbol is
--   interned
-- @treturn zile.Symbol newly initialised symbol.
local function define (name, value, symtab)
  symtab = symtab or obarray
  symtab[name] = make_symbol (name, value)
  return symtab[name]
end


--- Intern a symbol.
-- @string name symbol name
-- @tparam[opt=obarray] table symtab a table of @{zile.Symbol}s
--   interned
-- @treturn zile.Symbol interned symbol
local function intern (name, symtab)
  symtab = symtab or obarray
  if not symtab[name] then
    symtab[name] = make_symbol (name)
  end
  return symtab[name]
end


--- Check whether `name` was previously interned.
-- @string name possibly interned name
-- @tparam[opt=obarray] table symtab a table of @{zile.Symbol}s
-- @return symbol previously interned with `name`, or `nil`
local function intern_soft (name, symtab)
  return (symtab or obarray)[name]
end


--- Call a function on every symbol in `symtab`.
-- If `func` returns `true`, mapatoms returns immediately.
-- @func func a function that takes a symbol as its argument
-- @tparam[opt=obarray] table symtab a table of @{zile.Symbol}s
-- @return `true` if `func` signalled early exit by returning `true`,
--   otherwise `nil`
local function mapatoms (func, symtab)
  for _, symbol in pairs (symtab or obarray) do
    if func (symbol) then return true end
  end
end


--- @export
local methods = {
  define      = define,
  intern      = intern,
  intern_soft = intern_soft,
  make_symbol = make_symbol,
  mapatoms    = mapatoms,
}


return setmetatable (methods, {
  --- Return a new uninterned Symbol initialised from the given arguments.
  -- @function __call
  -- @string name symbol name
  -- @tparam[opt=obarray] table symtab a table of @{zile.Symbol}s
  --   interned
  -- @treturn zile.Symbol interned symbol
  __call = function (_, ...)
    return intern (...)
  end,
})
