-- Zz Evaluator
--
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
-- along with this program; see the file COPYING.  If not, write to the
-- Free Software Foundation, Fifth Floor, 51 Franklin Street, Boston,
-- MA 02111-1301, USA.



--[[ ==================== ]]--
--[[ Variable Management. ]]--
--[[ ==================== ]]--


local metadata = {}  -- variable docs and other metadata


-- Make a proxy table for main variables stored according to canonical
-- "_" delimited format, along with metamethods that access the proxy
-- while transparently converting to and from zlisp "-" delimited
-- format.
main_vars = {}


function Defvar (name, value, doc)
  main_vars[name] = value
  metadata[name] = { doc = texi (doc:chomp ()) }
end


function set_variable_buffer_local (name, bool)
  return rawset (metadata[name], "islocal", not not bool)
end


function get_variable (name, bp)
  return ((bp or cur_bp or {}).vars or main_vars)[name]
end


function get_variable_number (name, bp)
  return tonumber (get_variable (name, bp), 10)
end


function get_variable_bool (name, bp)
  return get_variable (name, bp) ~= "nil"
end


function get_variable_doc (name)
  local t = metadata[name]
  return t and t.doc or ""
end


function get_variable_table ()
  return main_vars
end


function set_variable (name, value, bp)
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

-- Initialise buffer local variables.
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


-- The symbol table is a symbol-name:symbol-func-table mapping.
local sandbox = {}


-- Call an interactive command.
local function call_command (f, ...)
  thisflag = {defining_macro = lastflag.defining_macro}

  -- Execute the command.
  command.interactive_enter ()
  local ok = f (...)
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


-- Shared metatable for symbol-func-tables.
local symbol_mt = {
  __call        = function (self, ...)
                    local args = {...}
                    for i, v in ipairs (args) do
                      -- When given, argtypes must match, though "function"
                      -- can match anything callable.
                      if self.argtypes
                         and not (self.argtypes[i] == type (v)
                                  or self.argtypes[i] == "function" and iscallable (v))
                      then
                        -- Undo mangled prefix_arg when called from minibuf.
                        if i == 1 and args[1] == prefix_arg then
                          args[1] = nil
                        else
                          return minibuf_error (
                            string.format (
                              "bad argument #%d to '%s' (%s expected, got %s): %s",
                              i, self.name, self.argtypes[i], type (v), tostring (v))
                          )
                        end
                      end
                    end
                    current_prefix_arg = prefix_arg
                    prefix_arg = false
                    local ret = call_command (self.func, unpack (args))
                    if ret == nil then
                      ret = true
                    end
                    return ret
                  end,

  __tostring    = function (self)
	            return self.name
	          end,
}



-- Define symbols for the evaluator.
local function Defun (name, argtypes, doc, interactive, func)
  local introspect = {
    argtypes    = argtypes,
    doc         = texi (doc:chomp ()),
    func        = func,
    interactive = interactive,
    name        = name,
  }
  sandbox[name] = setmetatable (introspect, symbol_mt)
end


-- Return function's interactive field, or nil if not found.
local function get_function_interactive (name)
  local value = sandbox[name]
  return value and value.interactive or nil
end


-- Evaluate a string of Lua.
local function evaluate_string (s)
  local f, errmsg = load (s, nil, 't', sandbox)
  if f == nil then
    return nil, errmsg
  end
  return f ()
end


-- Evaluate a file of Lua.
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


return {
  sandbox = sandbox,
  Defun   = Defun,
  Defvar  = Defvar,

  get_function_interactive   = get_function_interactive,

  call_command     = call_command,
  loadstring       = evaluate_string,
  loadfile         = evaluate_file,
}
