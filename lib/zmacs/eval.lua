-- Copyright (c) 2009-2013 Free Software Foundation, Inc.
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

--[[--
 Zmacs Lisp Evaluator.

 Extends the base ZLisp Interpreter with a func-table symbol type,
 that can be called like a regular function, but also contains its own
 metadata.  Additionally, like ELisp, we keep variables in their own
 namespace, and give each buffer it's own local list of variables for
 the various buffer-local variables we want to provide.

 Compared to the basic ZLisp Interpreter, this evaluator has to do
 a lot more work to keep an undo list, allow recording of keyboard
 macros and, again like Emacs, differentiate between interactive and
 non-interactive calls.

 @module zmacs.eval
]]


local lisp = require "zile.zlisp"
local Cons = lisp.Cons



--[[ ======================== ]]--
--[[ Symbol Table Management. ]]--
--[[ ======================== ]]--


--- Convert a '-' delimited symbol-name to be '_' delimited.
-- @function mangle
-- @string name a '-' delimited symbol-name
-- @treturn string `name` with all '-' transformed into '_'.
local mangle = memoize (function (name)
  return name and name:gsub ("%-", "_")
end)


--- Fetch the value of a previously defined symbol name.
-- Handle symbol name mangling transparently.
-- @string name the symbol name
-- @return the associated symbol value if any, else `nil`
local function fetch (name)
  return lisp.fetch (mangle (name))
end


local Defun, marshaller, namer, setter -- forward declarations


------
-- A named symbol and associated data.
-- @string name symbol name
-- @func func symbol's value as a function
-- @field value symbol's value as a variable
-- @tfield table plist property list associations for symbol
-- @table symbol


--- Define a command in the execution environment for the evaluator.
-- @string name command name
-- @tparam table argtypes a list of type strings that arguments must match
-- @string doc docstring
-- @bool interactive `true` if this command can be called interactively
-- @func func function to call after marshalling arguments
function Defun (name, argtypes, doc, interactive, func)
  local symbol = {
    name  = name,
    func  = func,
    plist = {
      ["marshall-argtypes"]      = argtypes,
      ["function-documentation"] = texi (doc:chomp ()),
      ["interactive-form"]       = interactive,
    },
  }

  lisp.define (mangle (name),
    setmetatable (symbol, {
      __call     = marshaller,
      __index    = symbol.plist,
      __newindex = setter,
      __tostring = namer,
    })
  )
end


--- Argument marshalling and type-checking for zlisp function symbols.
-- Used as the `__call` metamethod for function symbols.
-- @local
-- @tparam symbol symbol a symbol
-- @tparam zile.Cons arglist arguments for calling this function symbol
-- @return result of calling this function symbol
function marshaller (symbol, arglist)
  local argtypes = symbol["marshall-argtypes"]
  local args, i = {}, 1

  while arglist and arglist.car do
    local val, ty = arglist.car, argtypes[i]
    if ty == "number" then
      val = tonumber (val.value, 10)
    elseif ty == "boolean" then
      val = val.value ~= "nil"
    elseif ty == "string" then
      val = tostring (val.value)
    end
    table.insert (args, val)
    arglist = arglist.cdr
    i = i + 1
  end

  current_prefix_arg, prefix_arg = prefix_arg, false

  return symbol.func (unpack (args)) or true
end


--- Easy symbol name access with @{tostring}.
-- Used as the `__tostring` metamethod of symbols.
-- @local
-- @tparam symbol symbol a symbol
-- @treturn string name of this symbol
function namer (symbol)
  return symbol.name
end


--- Set a property on a symbol.
-- Used as the `__newindex` metamethod of symbols.
-- @local
-- @tparam symbol symbol a symbol
-- @string propname name of property to set
-- @param value value to store in property `propname`
-- @return the new `value`
function setter (symbol, propname, value)
  return rawset (symbol.plist, propname, value)
end



--[[ ==================== ]]--
--[[ Variable Management. ]]--
--[[ ==================== ]]--


--- Define a new variable.
-- Store the value and docstring for a variable for later retrieval.
-- @string name variable name
-- @param value value to store in variable `name`
-- @string doc variable's docstring
local function Defvar (name, value, doc)
  doc = doc or ""
  local symbol = {
    name  = name,
    value = value,
    plist = {
      ["variable-documentation"] = texi (doc:chomp ()),
    }
  }

  lisp.define (mangle (name),
    setmetatable (symbol, {
      __index    = symbol.plist,
      __newindex = setter,
      __tostring = namer,
    })
  )
end


--- Set a variable's buffer-local behaviour.
-- Any variable marked this way becomes a buffer-local version of the
-- same when set in any way.
-- @string name variable name
-- @tparam bool bool `true` to mark buffer-local, `false` to unmark.
-- @treturn bool the new buffer-local status
local function set_variable_buffer_local (name, bool)
  local symbol = fetch (name)
  symbol["buffer-local-variable"] = not not bool or nil
end


--- Return the variable symbol associated with name in buffer.
-- @string name variable name
-- @tparam[opt=current buffer] buffer bp buffer to select
-- @return the value of `name` from buffer `bp`
local function fetch_variable (name, bp)
  name = mangle (name)
  local obarray = (bp or cur_bp or {}).obarray
  return obarray and obarray[name] or lisp.fetch (name)
end


--- Return the value of a variable in a particular buffer.
-- @string name variable name
-- @tparam[opt=current buffer] buffer bp buffer to select
-- @return the value of `name` from buffer `bp`
local function get_variable (name, bp)
  return (fetch_variable (name, bp) or {}).value
end


--- Coerce a variable value to a number.
-- @string name variable name
-- @tparam[opt=current buffer] buffer bp buffer to select
-- @treturn number the number value of `name` from buffer `bp`
local function get_variable_number (name, bp)
  return tonumber (get_variable (name, bp), 10)
end


--- Coerce a variable value to a boolean.
-- @string name variable name
-- @tparam[opt=current buffer] buffer bp buffer to select
-- @treturn bool the bool value of `name` from buffer `bp`
local function get_variable_bool (name, bp)
  return get_variable (name, bp) ~= "nil"
end


--- Assign a value to variable in a given buffer.
-- @string name variable name
-- @param value value to assign to `name`
-- @tparam[opt=current buffer] buffer bp buffer to select
-- @return the new value of `name` from buffer `bp`
local function set_variable (name, value, bp)
  local found = fetch (name)
  if found and found["buffer-local-variable"] then
    local symbol = {
      name  = name,
      value = value,
      plist = found.plist,
    }
    setmetatable (symbol, {
      __index    = symbol.plist,
      __newindex = setter,
      __tostring = namer,
    })

    bp = bp or cur_bp
    bp.obarray = bp.obarray or {}
    rawset (bp.obarray, mangle (name), symbol)

  elseif found then
    found.value = value
  else
    Defvar (name, value, "")
  end

  return value
end



--[[ ================ ]]--
--[[ ZLisp Evaluator. ]]--
--[[ ================ ]]--


--- Execute a function non-interactively.
-- @tparam symbol|string symbol_or_name symbol or name of function
--   symbol to execute
-- @param[opt=nil] uniarg a single non-table argument for `symbol_or_name`
local function execute_function (symbol_or_name, uniarg)
  local symbol, ok = symbol_or_name, false

  if type (symbol_or_name) ~= "table" then
    symbol = fetch (symbol_or_name)
  end

  if uniarg ~= nil and type (uniarg) ~= "table" then
    uniarg = Cons ({value = uniarg and tostring (uniarg) or nil})
  end

  command.attach_label (nil)
  ok = symbol and symbol (uniarg)
  command.next_label ()

  return ok
end


--- Call a zlisp command with arguments, interactively.
-- @tparam symbol symbol a value already passed to @{Defun}
-- @tparam zile.Cons arglist arguments for `name`
-- @return the result of calling `name` with `arglist`, or else `nil`
local function call_command (symbol, arglist)
  thisflag = {defining_macro = lastflag.defining_macro}

  -- Execute the command.
  command.interactive_enter ()
  local ok = execute_function (symbol, arglist)
  command.interactive_exit ()

  -- Only add keystrokes if we were already in macro defining mode
  -- before the function call, to cope with start-kbd-macro.
  if lastflag.defining_macro and thisflag.defining_macro then
    add_cmd_to_macro ()
  end

  if cur_bp and not command.was_labelled (":undo") then
    cur_bp.next_undop = cur_bp.last_undop
  end

  lastflag = thisflag

  return ok
end


--- Evaluate a single command expression.
-- @tparam zile.Cons list a cons list, where the first element is a
--   command name.
-- @return the result of evaluating `list`, or else `nil`
local function evaluate_command (list)
  return list and list.car and call_command (list.car.value, list.cdr) or nil
end


--- Evaluate one arbitrary expression.
-- This function is required to implement ZLisp special forms, such as
-- `setq`, where some nodes of the AST are evaluated and others are not.
-- @tparam zile.Cons node a node of the AST from @{zmacs.zlisp.parse}.
-- @treturn zile.Cons the result of evaluating `node`
local function evaluate_expression (node)
  if fetch (node.value) ~= nil then
    return node.quoted and node or evaluate_command (node)
  elseif node.value == "t" or node.value == "nil" then
    return node
  end
  return Cons (get_variable (node.value) or node)
end


--- Evaluate a string of zlisp code.
-- @function loadstring
-- @string s zlisp source
-- @return `true` for success, or else `nil` plus an error string
local function evaluate_string (s)
  local ok, list = pcall (lisp.parse, s)
  if not ok then return nil, list end

  while list do
    evaluate_command (list.car.value)
    list = list.cdr
  end
  return true
end


--- Evaluate a file of zlisp.
-- @function loadfile
-- @param file path to a file of zlisp code
-- @return `true` for success, or else `nil` plus an error string
local function evaluate_file (file)
  local s, errmsg = io.slurp (file)

  if s then
    s, errmsg = evaluate_string (s)
  end

  return s, errmsg
end


------
-- Call a function on every symbol in obarray.
-- If `func` returns `true`, mapatoms returns immediately.
-- @function mapatoms
-- @func func a function that takes a symbol as its argument
-- @tparam[opt=obarray] table symtab a table with symbol values
-- @return `true` if `func` signalled early exit by returning `true`,
--   otherwise `nil`


--- @export
return {
  Defun               = Defun,
  Defvar              = Defvar,
  call_command        = call_command,
  evaluate_expression = evaluate_expression,
  execute_function    = execute_function,
  fetch               = fetch,
  fetch_variable      = fetch_variable,
  get_variable_bool   = get_variable_bool,
  get_variable_number = get_variable_number,
  loadfile            = evaluate_file,
  loadstring          = evaluate_string,
  mapatoms            = lisp.mapatoms,
  set_variable        = set_variable,
  set_variable_buffer_local = set_variable_buffer_local,
}
