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
 Sandboxed Lua Evaluator.

 @module zz.eval
]]



--[[ ======================== ]]--
--[[ Symbol Table Management. ]]--
--[[ ======================== ]]--


--- Sandboxed evaluation environment.
-- A mapping of symbol-names to symbol-values.
local sandbox = {}

local Defun, marshaller, namer, setter -- forward declarations


------
-- A named symbol and associated data.
-- @table command
-- @string name command name
-- @tfield table a list of type strings that arguments must match
-- @string doc docstring
-- @bool interactive `true` if this command can be called interactively
-- @func func function to call after marshalling arguments


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

  sandbox[name] = setmetatable (symbol, {
    __call     = marshaller,
    __index    = symbol.plist,
    __newindex = setter,
    __tostring = namer,
  })
end


--- Argument marshalling and type-checking for function symbols.
-- Used as the `__call` metamethod for function symbols.
-- @local
-- @tparam symbal symbol a symbol
-- @param ... arguments for calling this function symbol
-- @return result of calling this function symbol
function marshaller (symbol, ...)
  local args, argtypes = {...}, symbol["marshall-argtypes"]

  for i, v in ipairs (args) do
    -- When given, argtypes must match, though "function" can match
    -- anything callable.
    if argtypes
       and not (argtypes[i] == type (v)
                or argtypes[i] == "function" and iscallable (v))
    then
      -- Undo mangled prefix_arg when called from minibuf.
      if i == 1 and args[1] == prefix_arg then
        args[1] = nil
      else
        return minibuf_error (
          string.format (
            "bad argument #%d to '%s' (%s expected, got %s): %s",
            i, symbol.name, argtypes[i], type (v), tostring (v))
        )
      end
    end
  end

  current_prefix_arg, prefix_arg = prefix_arg, false

  return symbol.func (...) or true
end


--- Easy symbol name access with @{tostring}.
-- Used as the `__tostring` method of symbols.
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


--- Fetch the value of a defined symbol name.
-- @string name the symbol name
-- @return the associated symbol value if any, else `nil`
local function fetch (name)
  return sandbox[name]
end


--- Call a function on every symbol in sandbox.
-- If `func` returns `true`, mapatoms returns immediately.
-- @func func a function that takes a symbol as its argument
-- @tparam[opt=sandbox] table symtab a table with symbol values
-- @return `true` if `func` signaled early exit by returning `true`,
--   otherwise `nil`.
local function mapatoms (func, symtab)
  for _, symbol in pairs (symtab or sandbox) do
    if func (symbol) then return true end
  end
end




--[[ ==================== ]]--
--[[ Variable Management. ]]--
--[[ ==================== ]]--


--- Variable docs and other metadata.
local metadata = {}


--- Mapping between variable names and values.
local main_vars = {}


--- Define a new variable.
-- Store the value and docstring for a variable for later retrieval.
-- @string name variable name
-- @param value value to store in variable `name`
-- @string doc variable's docstring
local function Defvar (name, value, doc)
  main_vars[name] = value
  metadata[name] = { doc = texi (doc:chomp ()) }
end


--- Set a variable's buffer-local behaviour.
-- Any variable marked this way becomes a buffer-local version of the
-- same when set in any way.
-- @string name variable name
-- @tparam bool bool `true` to mark buffer-local, `false` to unmark.
-- @treturn bool the new buffer-local status
local function set_variable_buffer_local (name, bool)
  return rawset (metadata[name], "islocal", not not bool)
end


--- Return the value of a variable in a particular buffer.
-- @string name variable name
-- @tparam[opt=current buffer] buffer bp buffer to select
-- @return the value of `name` from buffer `bp`
local function get_variable (name, bp)
  return ((bp or cur_bp or {}).vars or main_vars)[name]
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


--- Return a table of all variables.
-- @treturn table all variables and their values in a table
function get_variable_table ()
  return main_vars
end


--- Assign a value to a variable in a given buffer.
-- @string name variable name
-- @param value value to assign to `name`
-- @tparam[opt=current buffer] buffer bp buffer to select
-- @return the new value of `name` from buffer `bp`
local function set_variable (name, value, bp)
  local t = metadata[name]
  if t and t.islocal then
    bp = bp or cur_bp
    bp.vars = bp.vars or {}
    bp.vars[name] = value
  else
    main_vars[name]= value
  end

  return value
end

--- Initialise buffer local variables.
-- @tparam buffer bp a buffer
function init_buffer (bp)
  bp.vars = setmetatable ({}, {
    __index    = main_vars,

    __newindex = function (self, name, value)
		   local t = metadata[name]
		   if t and t.islocal then
		     return rawset (self, name, value)
		   else
		     return rawset (main_vars, name, value)
		   end
                 end,
  })

  if get_variable_bool ("auto_fill_mode", bp) then
    bp.autofill = true
  end
end



--[[ ================== ]]--
--[[ Command Evaluator. ]]--
--[[ ================== ]]--


--- Call a command with arguments, interactively.
-- @tparam symbol symbol a value already passed to @{Defun}
-- @param ... arguments for `cmd`
-- @return the result of calling `cmd` with arguments, or else `nil`
local function call_command (symbol, ...)
  thisflag = {defining_macro = lastflag.defining_macro}

  -- Execute the command.
  command.interactive_enter ()
  local ok = symbol (...)
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



--- Evaluate a string of Lua inside the evaluation environment sandbox.
-- @function loadstring
-- @string s Lua source
-- @return `true` for success, or else `nil` pluss an error string
local function evaluate_string (s)
  local f, errmsg = load (s, nil, 't', sandbox)
  if f == nil then
    return nil, errmsg
  end
  return f ()
end


--- Evaluate a file of Lua inside the evaluation environment sandbox.
-- @function loadfile
-- @string file path to a file of Lua code
-- @return `true` for success, or else `nil` pluss an error string
local function evaluate_file (file)
  local s, errmsg = io.slurp (file)

  if s then
    s, errmsg = evaluate_string (s)

    if s == nil and errmsg ~= nil then
      minibuf_error (string.format ("%s: %s", file:gsub ("^.*/", "..."), errmsg))
    end
    return true
  end

  return s, errmsg
end


--- @export
return {
  Defun               = Defun,
  Defvar              = Defvar,
  call_command        = call_command,
  fetch               = fetch,
  get_variable        = get_variable,
  get_variable_bool   = get_variable_bool,
  get_variable_number = get_variable_number,
  loadstring          = evaluate_string,
  loadfile            = evaluate_file,
  mapatoms            = mapatoms,
  sandbox             = sandbox,
  set_variable        = set_variable,
  set_variable_buffer_local = set_variable_buffer_local,
}
