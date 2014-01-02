-- Registers facility functions
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

local regs = {}

function register_isempty (reg)
  return not regs[term_bytetokey (reg)]
end

function register_store (reg, data)
  regs[term_bytetokey (reg)] = data
end

regnum = false

function insert_register ()
  insert_estr (regs[term_bytetokey (regnum)])
  return true
end

function write_registers_list (i)
  for i, r in pairs (regs) do
    if r then
      insert_string (string.format ("Register %s contains ", tostring (i)))
      r = tostring (r)

      if r == "" then
        insert_string ("the empty string\n")
      elseif r:match ("^%s+$") then
        insert_string ("whitespace\n")
      else
        local len = math.min (20, math.max (0, cur_wp.ewidth - 6)) + 1
        insert_string (string.format ("text starting with\n    %s\n", string.sub (r, 1, len)))
      end
    end
  end
end
