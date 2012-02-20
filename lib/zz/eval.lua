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

local name_to_key = memoize (function (name)
  return string.gsub (name, "-", "_")
end)


-- Make a proxy table for main variables stored according to canonical
-- "_" delimited format, along with metamethods that access the proxy
-- while transparently converting to and from zlisp "-" delimited
-- format.
main_vars = setmetatable ({values = {}}, {
  __index = function (self, name)
    return rawget (self.values, name_to_key (name))
  end,

  __newindex = function (self, name, value)
    return rawset (self.values, name_to_key (name), value)
  end,

  __pairs = function (self)
    return function (t, k)
	     local v, j = next (t, k and name_to_key (k) or nil)
	     return v and v:gsub ("_", "-") or nil, j
	   end, self.values, nil
  end,
})


function Defvar (name, value, doc)
  local key = name_to_key (name)
  main_vars[key] = value
  metadata[key] = { doc = texi (doc:chomp ()) }
end


function set_variable_buffer_local (name, bool)
  return rawset (metadata[name_to_key (name)], "islocal", not not bool)
end


function get_variable (name, bp)
  return ((bp or cur_bp or {}).vars or main_vars)[name_to_key (name)]
end


function get_variable_number (name, bp)
  return tonumber (get_variable (name, bp), 10)
end


function get_variable_bool (name, bp)
  return get_variable (name, bp) ~= "nil"
end


function get_variable_doc (name)
  local t = metadata[name_to_key (name)]
  return t and t.doc or ""
end


function get_variable_table ()
  return main_vars
end


function set_variable (name, value, bp)
  local key = name_to_key (name)
  local t = metadata[key]
  if t and t.islocal then
    bp = bp or cur_bp
    bp.vars = bp.vars or {}
    bp.vars[key] = value
  else
    main_vars[key]= value
  end

  return value
end

-- Initialise buffer local variables.
function init_buffer (bp)
  bp.vars = setmetatable ({}, {
    __index    = main_vars.values,

    __newindex = function (self, name, value)
	           local key = name_to_key (name)
		   local t = metadata[key]
		   if t and t.islocal then
		     return rawset (self, key, value)
		   else
		     return rawset (main_vars, key, value)
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


-- Return true if there is a symbol `name' in the symbol-table.
local function function_exists (name)
  return sandbox[name] ~= nil
end


-- Return the named symbol-func-table.
local function get_function_by_name (name)
  return sandbox[name]
end


-- Return the docstring for symbol-name.
local function get_function_doc (name)
  local value = sandbox[name]
  return value and value.doc or nil
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

  function_exists            = function_exists,
  get_function_by_name       = get_function_by_name,
  get_function_interactive   = get_function_interactive,
  get_function_doc           = get_function_doc,

  call_command     = call_command,
  loadstring       = evaluate_string,
  loadfile         = evaluate_file,
}
