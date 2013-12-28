-- Zile Lisp interpreter
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

zz = require "zmacs.zlisp"


local M = {
  -- Copy some commands into our namespace directly.
  command   = zz.symbol,
  commands  = zz.symbols,
  cons      = zz.cons,
}

local cons = M.cons



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


function M.Defvar (name, value, doc)
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



--[[ ======================== ]]--
--[[ Symbol Table Management. ]]--
--[[ ======================== ]]--


local symbol   = zz.symbol
local name_map = {}

-- Define symbols for the evaluator.
function M.Defun (name, argtypes, doc, interactive, func)
  zz.define (name, {
    doc = texi (doc:chomp ()),
    interactive = interactive,
    func = function (arglist)
             local args = {}
	     local i = 1
             while arglist and arglist.car do
               local val = arglist.car
               local ty = argtypes[i]
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
             current_prefix_arg = prefix_arg
             prefix_arg = false
             local ret = func (unpack (args))
             if ret == nil then
               ret = true
             end
             return ret
           end
  })

  -- Maintain a reverse map for looking up function names.
  name_map[symbol[name].func] = name
end


-- Return true if there is a symbol `name' in the symbol-table.
function M.function_exists (name)
  return symbol[name] ~= nil
end


-- Return the named function's handler.
function M.get_function_by_name (name)
  return symbol[name] and symbol[name].func
end


-- Return function's interactive field, or nil if not found.
function M.get_function_interactive (name)
  local value = symbol[name]
  return value and value.interactive or nil
end


-- Return the docstring for symbol `name'.
function M.get_function_doc (name)
  local value = symbol[name]
  return value and value.doc or nil
end


-- Return the name of function 'func'.
function get_function_name (func)
  return name_map[func]
end



--[[ ================ ]]--
--[[ ZLisp Evaluator. ]]--
--[[ ================ ]]--


-- Execute a function non-interactively.
function M.execute_function (func_or_name, uniarg)
  local func, ok = func_or_name, false

  if type (func_or_name) == "string" then
    func = symbol[func_or_name] and symbol[func_or_name].func or nil
  end

  if uniarg ~= nil and type (uniarg) ~= "table" then
    uniarg = cons ({value = uniarg and tostring (uniarg) or nil})
  end

  command.attach_label (nil)
  ok = func and func (uniarg)
  command.next_label ()

  return ok
end

-- Call an interactive command.
function M.call_command (func, list)
  thisflag = {defining_macro = lastflag.defining_macro}

  -- Execute the command.
  command.interactive_enter ()
  local ok = M.execute_function (func, list)
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


-- Evalute one command expression.
local function evalcommand (list)
  return list and list.car and M.call_command (list.car.value, list.cdr) or nil
end


-- Evaluate one arbitrary expression.
function M.evalexpr (node)
  if M.function_exists (node.value) then
    return node.quoted and node or evalcommand (node)
  elseif node.value == "t" or node.value == "nil" then
    return node
  end
  return cons (get_variable (node.value) or node)
end


-- Evaluate a string of ZLisp.
function M.loadstring (s)
  local ok, list = pcall (zz.parse, s)
  if not ok then return nil, list end

  local result = true
  while list do
    result = evalcommand (list.car.value)
    list = list.cdr
  end
  return result
end


-- Evaluate a file of ZLisp.
function M.loadfile (file)
  local s, errmsg = io.slurp (file)

  if s then
    s, errmsg = M.loadstring (s)
  end

  return s, errmsg
end


return M
