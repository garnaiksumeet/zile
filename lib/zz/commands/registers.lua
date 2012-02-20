-- Registers facility commands.
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

local eval = require "zz.eval"
local Defun, zz = eval.Defun, eval.sandbox


Defun ("copy_to_register",
  {"number"},
[[
Copy region into register @i{register}.
]],
  true,
  function (reg)
    if not reg then
      minibuf_write ('Copy to register: ')
      reg = getkey_unfiltered (GETKEY_DEFAULT)
    end

    if reg == 7 then
      return keyboard_quite ()
    else
      minibuf_clear ()
      local rp = calculate_the_region ()
      if not rp then
        return false
      else
        register_store (reg, get_buffer_region (cur_bp, rp))
      end
    end

    return true
  end
)


Defun ("insert_register",
  {"number"},
[[
Insert contents of the user specified register.
Puts point before and mark after the inserted text.
]],
  true,
  function (reg)
    local ok = true

    if warn_if_readonly_buffer () then
      return false
    end

    if not reg then
      minibuf_write ('Insert register: ')
      reg = getkey_unfiltered (GETKEY_DEFAULT)
    end

    if reg == 7 then
      ok = keyboard_quite ()
    else
      minibuf_clear ()
      if register_isempty (reg) then
        minibuf_error ('Register does not contain text')
        ok = false
      else
        zz.set_mark_command ()
	regnum = reg
        execute_with_uniarg (true, current_prefix_arg, insert_register)
        zz.exchange_point_and_mark ()
        deactivate_mark ()
      end
    end

    return ok
  end
)


Defun ("list_registers",
  {},
[[
List defined registers.
]],
  true,
  function ()
    write_temp_buffer ('*Registers List*', true, write_registers_list)
  end
)
