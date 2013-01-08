-- Callbacks required by Zile.
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

-- Used to process keyboard macros, and to maintain identical behaviour
-- between the user typing and a keyboard macro sending keys, also used
-- for the main loop after initialization.
function get_and_run_command ()
  local keys = get_key_sequence ()
  local name = get_function_by_keys (keys)

  minibuf_clear ()

  if eval.function_exists (name) then
    eval.call_command (name, lastflag.set_uniarg and (prefix_arg or 1))
  else
    minibuf_error (tostring (keys) .. " is undefined")
  end
end
