-- Copyright (c) 2009-2014 Free Software Foundation, Inc.
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

 A standard Lua execution environment as a table, with a small twist: In
 addition to regular `name = value` pairs, symbols with attached metadata
 are created by @{Defun} and @{Defvar}. But, the `__index` and `__newindex`
 metamethods of @{sandbox} let you dereference and change the values of
 even those symbols using regular Lua syntax.

 @module zz.eval
]]



--[[ ======================== ]]--
--[[ Symbol Table Management. ]]--
--[[ ======================== ]]--


--- Defun and Defvar defined symbols.
local symdef = setmetatable ({}, {__mode = "k"})

--- Sandboxed evaluation environment.
-- A mapping of symbol-names to symbol-values.
local sandbox = setmetatable ({
  ipairs   = ipairs,
  math     = math,
  next     = next,
  pairs    = pairs,
  string   = string,
  table    = table,
  tonumber = tonumber,
  tostring = tostring,
  type     = type,
}, {
  __index = function (self, name)
    if symdef[name] then return symdef[name].value end
  end,

  __newindex = function (self, name, value)
    if symdef[name] then
      symdef[name].value = value
    else
      rawset (self, name, value)
    end
  end,
})


local Defun, marshaller, namer, setter -- forward declarations


------
-- A named symbol and associated data.
-- @table symbol
-- @string name command name
-- @tfield table a list of type strings that arguments must match
-- @string doc docstring
-- @bool interactive `true` if this command can be called interactively
-- @param value symbol value


--- Define a command in the execution environment for the evaluator.
-- @string name command name
-- @tparam table argtypes a list of type strings that arguments must match
-- @string doc docstring
-- @bool interactive `true` if this command can be called interactively
-- @func func function to call after marshalling arguments
function Defun (name, argtypes, doc, interactive, func)
  local symbol = {
    name  = name,
    value = func,
    plist = {
      ["documentation"]     = texi (doc:chomp ()),
      ["interactive-form"]  = interactive,
      ["marshall-argtypes"] = argtypes,
    },
  }

  symdef[name] = setmetatable (symbol, {
    __call     = marshaller,
    __index    = symbol.plist,
    __newindex = setter,
    __tostring = namer,
  })

  return symbol
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

  return symbol.value (...) or true
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


--- Fetch a defined symbol by name.
-- @string name the symbol name
-- @return the associated symbol value if any, else `nil`
local function fetch (name)
  return symdef[name]
end


--- Call a function on every @{Defun}ed and @{Defvar}ed symbol.
-- If `func` returns `true`, mapatoms returns immediately.
-- @func func a function that takes a symbol as its argument
-- @tparam[opt=sandbox] table symtab a table with symbol values
-- @return `true` if `func` signaled early exit by returning `true`,
--   otherwise `nil`.
local function mapatoms (func, symtab)
  for _, symbol in pairs (symtab or symdef) do
    if func (symbol) then return true end
  end
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
  local symbol = {
    name  = name,
    value = value,
    plist = {
      ["documentation"] = texi (doc:chomp ()),
    },
  }

  symdef[name] = setmetatable (symbol, {
    __index    = symbol.plist,
    __newindex = setter,
    __tostring = namer,
  })

  return symbol
end


--- Set a variable's buffer-local behaviour.
-- Any variable marked this way becomes a buffer-local version of the
-- same when set in any way.
-- @string name variable name
-- @tparam bool bool `true` to mark buffer-local, `false` to unmark.
-- @treturn bool the new buffer-local status
local function set_variable_buffer_local (name, bool)
  return rawset (symdef[name], "buffer-local", bool or nil)
end


--- Return the variable symbol associated with name in buffer.
-- @string name variable name
-- @tparam[opt=current buffer] buffer bp buffer to select
-- @return the value of `name` from buffer `bp`
local function fetch_variable (name, bp)
  local obarray = (bp or cur_bp or {}).obarray
  return obarray and obarray[name] or symdef[name]
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
  return not not get_variable (name, bp)
end


--- Assign a value to a variable in a given buffer.
-- @string name variable name
-- @param value value to assign to `name`
-- @tparam[opt=current buffer] buffer bp buffer to select
-- @return the new value of `name` from buffer `bp`
local function set_variable (name, value, bp)
  local found = symdef[name]
  if found and found["buffer-local"] then
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
    rawset (bp.obarray, name, value)

  elseif found then
    found.value = value
  else
    Defvar (name, value, "")
  end

  return value
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
