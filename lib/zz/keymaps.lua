-- Zz key mappings
--
-- Copyright (c) 2010-2014 Free Software Foundation, Inc.
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

local eval  = require "zz.eval"
local posix = require "posix"

root_bindings = tree.new ()

function init_default_bindings ()
  -- Bind all printing keys to self-insert-command
  for i = 0, 0xff do
    if posix.isprint (string.char (i)) then
      root_bindings[{keycode (string.char (i))}] = eval.sandbox.self_insert_command
    end
  end

  -- Bind special key names to self-insert-command
  list.map (function (e)
              root_bindings[{keycode (e)}] = eval.sandbox.self_insert_command
            end,
            {"\\SPC", "\\TAB", "\\RET", "\\\\"})

  -- Search package.path for default-bindings.el, and load it.
  local ok, errmsg
  package.path:gsub ("[^;]+",
                    function (path)
                      if ok == nil then
                        path = path:gsub ("%?", "zz/default-bindings", 1)
                        ok, errmsg = eval.loadfile (path)
                      end
                    end)
  return ok, errmsg
end
