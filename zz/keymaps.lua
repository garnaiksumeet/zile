-- Zz key mappings
--
-- Copyright (c) 2010-2013 Free Software Foundation, Inc.
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

eval = require "eval"

root_bindings = tree.new ()

function init_default_bindings ()
  -- Bind all printing keys to self_insert_command
  for i = 0, 0xff do
    if posix.isprint (string.char (i)) then
      root_bindings[{keycode (string.char (i))}] = "self_insert_command"
    end
  end

  -- Bind special key names to self_insert_command
  list.map (function (e)
              root_bindings[{keycode (e)}] = "self_insert_command"
            end,
            {"\\SPC", "\\TAB", "\\RET", "\\\\"})

  eval.loadfile (PATH_DATA .. "/emacs-bindings.lua")
end
