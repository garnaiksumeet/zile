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



--[[ ======== ]]--
--[[ Imports. ]]--
--[[ ======== ]]--


local Symbol = require "zile.Symbol"


--- Defun and Defvar defined symbols.
-- @table symtab
local symtab = setmetatable ({}, {__mode = "k"})


--- Call a function on every symbol in @{symtab}
-- If `func` returns `true`, mapatoms returns immediately.
-- @func func a function that takes a symbol as its argument
-- @tparam[opt=symtab] table symbols a table of symbols
-- @return `true` if `func` signalled early exit by returning `true`,
--   otherwise `nil`
local function mapatoms (func, symbols)
  return Symbol.mapatoms (func, symbols or symtab)
end


--- Return a new interned @{symbol} initialised from the given arguments.
-- @string name symbol name
-- @tparam[opt=symtab] table symbols a table of symbols
-- @treturn symbol interned symbol
local function intern (name, symbols)
  return Symbol.intern (name, symbols or symtab)
end


--- Fetch a defined symbol by name.
-- @string name the symbol name
-- @tparam[opt=symtab] table symbols a table of symbols
-- @treturn symbol symbol previously interned with `name`, else `nil`
local function fetch (name, symbols)
  return Symbol.intern_soft (name, symbols or symtab)
end



--[[ ======================== ]]--
--[[ Symbol Table Management. ]]--
--[[ ======================== ]]--


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
    if symtab[name] then return symtab[name].value end
  end,

  __newindex = function (self, name, value)
    if symtab[name] then
      symtab[name].value = value
    else
      rawset (self, name, value)
    end
  end,
})


--- Turn texinfo markup into plain text
-- @string s a string with a subset of texinfo markup.
-- @treturn a copy of `s` with markup expanded as plain text
local function texi (s)
  s = string.gsub (s, "@i{([^}]+)}", function (s) return string.upper (s) end)
  s = string.gsub (s, "@kbd{([^}]+)}", "%1")
  s = string.gsub (s, "@samp{([^}]+)}", "%1")
  s = string.gsub (s, "@itemize%s[^\n]*\n", "")
  s = string.gsub (s, "@end%s[^\n]*\n", "")
  return s
end

local Defun, marshaller -- forward declarations


------
-- A named symbol and associated metadata.
-- Zz symbols are _lisp-1_ style, where a symbol can hold only one value
-- at a time; like scheme.
-- Property list keys can be any string - some internally used keys are:
-- `documentation`, `interactive-form` and `buffer-local`.
-- @table symbol
-- @string name symbol name
-- @field[opt=nil] value symbol value
-- @tfield[opt={}] table plist property list


--- Define a command in the execution environment for the evaluator.
-- @string name command name
-- @tparam table argtypes a list of type strings that arguments must match
-- @string doc docstring
-- @bool interactive `true` if this command can be called interactively
-- @func func function to call after marshalling arguments
-- @treturn symbol newly interned symbol
function Defun (name, argtypes, doc, interactive, func)
  local symbol = intern (name, symtab)
  symbol.value = func
  symbol["documentation"]      = texi (doc:chomp ())
  symbol["interactive-form"]   = interactive
  symbol["marshall-argtypes"]  = argtypes
  getmetatable (symbol).__call = marshaller
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



--[[ ==================== ]]--
--[[ Variable Management. ]]--
--[[ ==================== ]]--


--- Define a new variable.
-- Store the value and docstring for a variable for later retrieval.
-- @string name variable name
-- @param value value to store in variable `name`
-- @string doc variable's docstring
local function Defvar (name, value, doc)
  local symbol = intern (name, symtab)
  symbol.value = value
  symbol["documentation"] = texi (doc:chomp ())
  return symbol
end


--- Set a variable's buffer-local behaviour.
-- Any variable marked this way becomes a buffer-local version of the
-- same when set in any way.
-- @string name variable name
-- @tparam bool bool `true` to mark buffer-local, `false` to unmark.
-- @treturn bool the new buffer-local status
local function set_variable_buffer_local (name, bool)
  local symbol = intern (name, symtab)
  symbol["buffer-local"] = bool or nil
end


--- Return the variable symbol associated with name in buffer.
-- @string name variable name
-- @tparam[opt=current buffer] buffer bp buffer to select
-- @return the value of `name` from buffer `bp`
local function fetch_variable (name, bp)
  local obarray = (bp or cur_bp or {}).obarray
  return obarray and fetch (name, obarray) or fetch (name, symtab)
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
  local found = fetch (name, symtab)
  if found and found["buffer-local"] then
    bp = bp or cur_bp
    bp.obarray = bp.obarray or {}

    local symbol = intern (name, bp.obarray)
    symbol.value = value
    getmetatable (symbol).__index = found.plist

  elseif found then
    found.value = value
  else
    Defvar (name, value, "")
  end

  return value
end



--[[ ================== ]]--
--[[ Sandbox Evaluator. ]]--
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
local function eval_string (s)
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
local function eval_file (file)
  local s, errmsg = io.slurp (file)

  if s then
    s, errmsg = eval_string (s)

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
  loadstring          = eval_string,
  loadfile            = eval_file,
  mapatoms            = mapatoms,
  sandbox             = sandbox,
  set_variable        = set_variable,
  set_variable_buffer_local = set_variable_buffer_local,
}
