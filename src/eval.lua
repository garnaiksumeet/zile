-- Zile Lua Evaluator
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


local M = {}

-- User commands
local usercmd = {}
local cmdmeta = {}

function M.Defun (name, argtypes, doc, interactive, func)
  usercmd[name] = function (...)
    local args = {...}
    for i, v in ipairs (args) do
      if argtypes and argtypes[i] and argtypes[i] ~= type (v) then
        -- Undo mangled prefix_arg when called from mini-buffer
        if i == 1 and args[1] == prefix_arg then
          args[1] = nil
        else
          return minibuf_error (string.format ("wrong type %s for argument #%d `%s', should be %s",
                                  type (v), i, tostring (v), argtypes[i]))
        end
      end
    end
    current_prefix_arg = prefix_arg
    prefix_arg = false
    local ret = M.call_command (func, unpack (args))
    if ret == nil then
      ret = true
    end
    return ret
  end
  cmdmeta[usercmd[name]] = {
    doc = texi (doc:chomp ()),
    interactive = interactive,
    name = name,
  }
end

-- Return function's interactive field, or nil if not found.
function M.get_function_interactive (name)
  local f = usercmd[name]
  return f and cmdmeta[f].interactive or nil
end

function M.get_function_doc (name)
  local f = usercmd[name]
  return k and cmdmeta[f].doc or nil
end

-- Iterator returning (name, func) for each usercmd.
function M.commands ()
  return next, usercmd, nil
end

-- Execute a function non-interactively.
function M.execute_function (f, ...)
  local ok

  -- FIXME: just pass the function always!!
  if type (f) == "string" then f = usercmd[f] end

  command.attach_label (nil)
  ok = f and f (...)
  command.next_label ()

  return ok
end

-- Call an interactive command.
function M.call_command (f, ...)
  thisflag = {defining_macro = lastflag.defining_macro}

  -- Execute the command.
  command.interactive_enter ()
  local ok = M.execute_function (f, ...)
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

function M.loadstring (s)
  local f, errmsg = load (s, nil, 't', usercmd)
  if f == nil then
    return nil, errmsg
  end
  return f ()
end

function M.loadfile (file)
  local s = io.slurp (file)

  if s then
    local res, errmsg = M.loadstring (s)

    if res == nil and errmsg ~= nil then
      minibuf_error (string.format ("%s: %s", file, errmsg))
    end
    return true
  end

  return false
end

function M.function_exists (name)
  return usercmd[name] ~= nil
end

return M
