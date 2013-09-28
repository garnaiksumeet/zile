-- Zile variables handling functions
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


-- FIXME: Use a table with default values

function get_variable (var)
  return get_variable_bp (cur_bp, var)
end

function get_variable_bp (bp, var)
  -- prefer Defvar'ed name for value lookup.
  local key = varname_map[var] or var
  return ((bp and bp.vars and bp.vars[key]) or main_vars[key] or {}).val
end

function get_variable_number_bp (bp, var)
  return tonumber (get_variable_bp (bp, var), 10)
  -- FIXME: Check result and signal error.
end

function get_variable_number (var)
  return get_variable_number_bp (cur_bp, var)
end

function get_variable_bool (var)
  local p = get_variable (var)
  if p then
    return p ~= "nil"
  end

  return false
end

function set_variable (var, val)
  local key = varname_map[var] or var
  local vars
  if (main_vars[key] or {}).islocal then
    cur_bp.vars = cur_bp.vars or {}
    vars = cur_bp.vars
  else
    vars = main_vars
  end
  vars[key] = vars[key] or {}

  vars[key].val = val
end
