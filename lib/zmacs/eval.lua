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
  commands  = zz.symbols,
  cons      = zz.cons,
}

local cons = M.cons



--[[ ==================== ]]--
--[[ Variable Management. ]]--
--[[ ==================== ]]--


-- Some of the code in lib.zile behaves differently depending on the
-- values of variables Defvar'd below, but the variable names exposed
-- to the user may not be appropriate in some editor implementations,
-- so we maintain 'varname_map' as a way of translating from the
-- lookups with editor sepecific names into the canonical keys used
-- to actually store the variable metadata.
varname_map = {}

main_vars = {}

function M.Defvar (name, value, doc, local_when_set)
  -- Zmacs variables use '-' in place of '_' for user visible names.
  local key = name:gsub ("-", "_")

  varname_map [name] = key
  main_vars[key] = {
    val = value,
    doc = texi (doc:chomp ()),
    islocal = local_when_set,
  }
end


--[[ ======================== ]]--
--[[ Symbol Table Management. ]]--
--[[ ======================== ]]--


local symbol = zz.symbol

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
end


-- Return true if there is a symbol `name' in the symbol-table.
function M.function_exists (name)
  return symbol[name] ~= nil
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



--[[ ================ ]]--
--[[ ZLisp Evaluator. ]]--
--[[ ================ ]]--


-- Execute a function non-interactively.
function M.execute_function (name, uniarg)
  local ok

  if uniarg ~= nil and type (uniarg) ~= "table" then
    uniarg = cons ({value = uniarg and tostring (uniarg) or nil})
  end

  command.attach_label (nil)
  local value = symbol[name]
  ok = value and value.func and value.func (uniarg)
  command.next_label ()

  return ok
end

-- Call an interactive command.
function M.call_command (name, list)
  thisflag = {defining_macro = lastflag.defining_macro}

  -- Execute the command.
  command.interactive_enter ()
  local ok = M.execute_function (name, list)
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
