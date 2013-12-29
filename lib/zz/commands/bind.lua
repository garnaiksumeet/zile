-- Key bindings and extended commands.
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

local eval  = require "zz.eval"
local Defun, fetch = eval.Defun, eval.fetch


Defun ("self_insert_command",
  {},
[[
Insert the character you type.
Whichever character you type to run this command is inserted.
]],
  true,
  function ()
    return execute_with_uniarg (true, current_prefix_arg, self_insert_command)
  end
)


Defun ("where_is",
  {},
[[
Print message listing key sequences that invoke the command DEFINITION.
Argument is a command name.
]],
  true,
  function ()
    local name = minibuf_read_function_name ('Where is command: ')

    if name and fetch (name) then
      local g = { f = name, bindings = '' }

      walk_bindings (root_bindings, gather_bindings, g)

      if #g.bindings == 0 then
        minibuf_write (name .. ' is not on any key')
      else
        minibuf_write (string.format ('%s is on %s', name, g.bindings))
      end
      return true
    end
  end
)


local function print_binding (key, func)
  insert_string (string.format ('%-15s %s\n', key, tostring (func)))
end


local function write_bindings_list (keyx, binding)
  insert_string ('Key translations:\n')
  insert_string (string.format ('%-15s %s\n', 'key', 'binding'))
  insert_string (string.format ('%-15s %s\n', '---', '-------'))

  walk_bindings (root_bindings, print_binding)
end


Defun ("describe_bindings",
  {},
[[
Show a list of all defined keys, and their definitions.
]],
  true,
  function ()
    write_temp_buffer ('*Help*', true, write_bindings_list)
    return true
  end
)


Defun ("global_set_key",
  {"string", "function"},
[[
Bind a command to a key sequence.
Read key sequence and function name, and bind the function to the key
sequence.
]],
  true,
  function (keystr, func)
    local keys = prompt_key_sequence ('Set key globally', keystr)

    if keystr == nil then
      keystr = tostring (keys)
    end

    if not func then
      local name = minibuf_read_function_name (string.format ('Set key %s to command: ', keystr))
      if name then
        func = lisp.sandbox[name]
      end
      if not func then return false end
    end

    if func == nil then -- Possible if called non-interactively
      return minibuf_error (string.format ([[No such function `%s']], tostring (func)))
    end

    root_bindings[keys] = func
    return true
  end
)


Defun ("global_unset_key",
  {"string"},
[[
Remove global binding of a key sequence.
Read key sequence and unbind any function already bound to that sequence.
]],
  true,
  function (keystr)
    local keys = prompt_key_sequence ('Unset key globally', keystr)

    if keystr == nil then
      keystr = tostring (keys)
    end

    root_bindings[keys] = nil

    return true
  end
)


Defun ("universal_argument",
  {},
[[
Begin a numeric argument for the following command.
Digits or minus sign following @kbd{C-u} make up the numeric argument.
@kbd{C-u} following the digits or minus sign ends the argument.
@kbd{C-u} without digits or minus sign provides 4 as argument.
Repeating @kbd{C-u} without digits or minus sign multiplies the argument
by 4 each time.
]],
  true,
  function ()
    local ok = true

    -- Need to process key used to invoke universal_argument.
    pushkey (lastkey ())

    thisflag.uniarg_empty = true

    local i = 0
    local arg = 1
    local sgn = 1
    local keys = {}
    while true do
      local as = ''
      local key = do_binding_completion (table.concat (keys, ' '))

      -- Cancelled.
      if key == keycode '\\C-g' then
        ok = keyboard_quit ()
        break
      -- Digit pressed.
      elseif key.key < 256 and string.match (string.char (key.key), '%d') then
        local digit = key.key - string.byte ('0')
        thisflag.uniarg_empty = false

        if key.META then
          as = 'ESC '
        end

        as = as .. string.format ('%d', digit)

        if i == 0 then
          arg = digit
        else
          arg = arg * 10 + digit
        end

        i = i + 1
      elseif key == keycode '\\C-u' then
        as = as .. 'C-u'
        if i == 0 then
          arg = arg * 4
        else
          break
        end
      elseif key == keycode '\\M--' and i == 0 then
        if sgn > 0 then
          sgn = -sgn
          as = as .. '-'
          -- The default negative arg is -1, not -4.
          arg = 1
          thisflag.uniarg_empty = false
        end
      else
        ungetkey (key)
        break
      end

      table.insert (keys, as)
    end

    if ok then
      prefix_arg = arg * sgn
      thisflag.set_uniarg = true
      minibuf_clear ()
    end

    return ok
  end
)


Defun ("keyboard_quit",
  {},
[[
Cancel current command.
]],
  true,
  keyboard_quit
)


Defun ("suspend_zz",
  {},
[[
Stop and return to superior process.
]],
  true,
  suspend
)
