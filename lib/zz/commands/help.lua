-- Self documentation facility commands.
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
-- along with this program.  If not, see <htt://www.gnu.org/licenses/>.

local eval = require "zz.eval"
local Defun, fetch, zz = eval.Defun, eval.fetch, eval.sandbox


local function write_function_description (command)
  insert_string (string.format (
     '%s is %s built-in function in ' .. [[`Lua source code']] .. '.\n\n%s',
     tostring (command),
     command['interactive-form'] and 'an interactive' or 'a',
     command['documentation']))
end


Defun ("describe_function",
  {"string"},
[[
Display the full documentation of a function.
]],
  true,
  function (name)
    name = name or minibuf_read_function_name ('Describe function: ')
    local func = eval.fetch (name)
    if not func or not func['documentation'] then return false end

    write_temp_buffer ('*Help*', true, write_function_description, func)
    return true
  end
)


local function write_key_description (command, binding)
  insert_string (string.format (
    '%s runs the command %s, which is %s built-in\n' ..
    'function in ' .. [[`Lua source code']] .. '.\n\n%s',
    binding,
    tostring (command),
    command['interactive-form'] and 'an interactive' or 'a',
    command['documentation']))
end


Defun ("describe_key",
  {"string"},
[[
Display documentation of the command invoked by a key sequence.
]],
  true,
  function (keystr)
    local command, binding
    if keystr then
      local keys = keystrtovec (keystr)
      if not keys then
        return false
      end
      command = get_function_by_keys (keys, fetch)
      binding = tostring (keys)
    else
      minibuf_write ('Describe key:')
      local keys = get_key_sequence ()
      command = get_function_by_keys (keys, fetch)
      binding = tostring (keys)

      if not command then
        return minibuf_error (binding .. ' is undefined')
      end
    end

    minibuf_write (string.format ([[%s runs the command `%s']], binding, tostring (command)))
    if not command['function-documentation'] then return false end

    write_temp_buffer ('*Help*', true, write_key_description, command, binding)
    return true
  end
)


local function write_variable_description (symbol)
  insert_string (string.format (
    '%s is a variable defined in ' .. [[`Lua source code']] .. '.\n\n' ..
    'Its value is %s\n\n%s',
    tostring (symbol), symbol.value, symbol['documentation']))
end


Defun ("describe_variable",
  {"string"},
[[
Display the full documentation of a variable.
]],
  true,
  function (name)
    name = name or minibuf_read_variable_name ('Describe variable: ')
    local symbol = eval.fetch (name)
    if not symbol or not symbol['documentation'] then return false end
    write_temp_buffer ('*Help*', true, write_variable_description, symbol)
    return true
  end
)


local function find_or_create_buffer_from_module (name)
  local bp = find_buffer (name)
   if bp then
     switch_to_buffer (bp)
   else
     bp = create_auto_buffer (name)
     switch_to_buffer (bp)
     insert_string (require ('zz.doc.' .. name))
   end
   cur_bp.readonly = true
   cur_bp.modified = false
  goto_offset (1)
end


Defun ("describe_copying",
  {},
[[
Display info on how you may redistribute copies of GNU Zz.
]],
  true,
  function ()
    find_or_create_buffer_from_module ('COPYING')
  end
)


Defun ("describe_no_warranty",
  {},
[[
Display info on all the kinds of warranty Zz does NOT have.
]],
  true,
  function ()
    find_or_create_buffer_from_module ('COPYING')
    zz.search_forward (' Disclaimer of Warranty.')
    beginning_of_line ()
  end
)


Defun ("view_zz_FAQ",
  {},
[[
Display the Zz Frequently Asked Questions (FAQ) file.
]],
  true,
  function ()
    find_or_create_buffer_from_module ('FAQ')
  end
)


Defun ("view_zz_news",
  {},
[[
Display info on recent changes to Zz.
]],
  true,
  function ()
    find_or_create_buffer_from_module ('NEWS')
  end
)
