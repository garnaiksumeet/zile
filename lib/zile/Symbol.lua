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
 in the global symbol table `obarray`, and is then considered _interned_.

 Symbols can also be interned into some other symbol table, by passing
 a different Lua table reference to the appropriate parameter of the
 functions in this module.

 Create a new uninterned symbol with:

     > Symbol = require "zile.Symbol"
     > sym = Symbol.make_symbol ("answer", 42)

 Alternatively, create an interned symbol with:

     > bol = Symbol ("question")
     > bol.value = "6 times 7"

 And retrieve it with:

     > =(bol == Symbol.intern_soft "question")
     true

 @classmod zile.Symbol
]]



--- Default symbol table.
-- A mapping of symbol-names to symbol-values.  _Interned_ symbols are
-- stored here.
--
-- There is no way to access the contents of the default symbol table,
-- except to use the @{mapatoms} function.
-- @table obarray
local obarray = {}


------
-- A symbol.
--
-- This is not an actual interface element you can access in this module,
-- but serves to document the layout of the symbols produced by this
-- module.
--
-- Access the name and value with the dot operator:
--
--     > =sym.name
--     answer
--     > =sym.value
--     42
--     > sym.value = "a string"
--     > =sym.value
--     a string
--
-- Symbols also have a property list; a mapping of property names to
-- property to values.  Use the `[]` operator to access the property
-- list.
--
--     > =sym["prop-name"]
--     nil
--     > sym["prop-name"] = "some value"
--     > =sym["prop-name"]
--     some value
--
-- `tostring(symbol)` returns `symbol.name`.
-- @table symbol
-- @string name symbol name
-- @field[opt=nil] value symbol value
-- @tfield[opt={}] table plist property list


--- Return a string representation of the value of a variable.
-- @tparam symbol symbol a symbol
-- @treturn string string representation, suitable for display
local function display_variable_value (symbol)
  local value = symbol.value
  if type (value) == "string" then
    return '"' .. value:gsub ('"', '\\"') .. '"'
  end
  return tostring (value)
end


--- Make a new, uninterned, symbol.
-- @string name symbol name
-- @param[opt=nil] value value to store in new symbol
-- @tparam[opt={}] table plist property list for new symbol
-- @treturn symbol newly initialised symbol
local function make_symbol (name, value, plist)
  local symbol = {
    name  = name,
    value = value,
    plist = plist or {},
  }

  return setmetatable (symbol, {
    _type      = "Symbol",
    __index    = symbol.plist,
    __newindex = function (self, propname, value)
	           if propname == 'name' or propname == 'value' then
		     return rawset (self, propname, value)
		   end
                   return rawset (self.plist, propname, value)
		 end,
    __tostring = display_variable_value,
  })
end


--- Is `x` a Symbol object?
-- @param x a Lua object
-- @return `true` if `x` is a Symbol object, or else `false`
local function symbolp (x)
  return (getmetatable (x) or {})._type == "Symbol"
end


--- Intern a symbol.
-- @string name symbol name
-- @tparam[opt=obarray] table symtab a table of @{symbol}s
--   interned
-- @treturn symbol interned symbol
local function intern (name, symtab)
  symtab = symtab or obarray
  if not symtab[name] then
    symtab[name] = make_symbol (name)
  end
  return symtab[name]
end


--- Check whether `name` was previously interned.
-- @string name possibly interned name
-- @tparam[opt=obarray] table symtab a table of @{symbol}s
-- @return symbol previously interned with `name`, or `nil`
local function intern_soft (name, symtab)
  return (symtab or obarray)[name]
end


--- Call a function on every symbol in `symtab`.
-- If `func` returns `true`, mapatoms returns immediately.
-- @func func a function that takes a symbol as its argument
-- @tparam[opt=obarray] table symtab a table of @{symbol}s
-- @return `true` if `func` signalled early exit by returning `true`,
--   otherwise `nil`
local function mapatoms (func, symtab)
  for _, symbol in pairs (symtab or obarray) do
    if func (symbol) then return true end
  end
end


--- @export
local methods = {
  intern      = intern,
  intern_soft = intern_soft,
  make_symbol = make_symbol,
  mapatoms    = mapatoms,
  symbolp     = symbolp,
}


return setmetatable (methods, {
  --- Return a new uninterned Symbol initialised from the given arguments.
  -- @function __call
  -- @string name symbol name
  -- @tparam[opt=obarray] table symtab a table of @{symbol}s
  --   interned
  -- @treturn symbol interned symbol
  __call = function (_, ...)
    return intern (...)
  end,
})
