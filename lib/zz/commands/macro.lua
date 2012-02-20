-- Macro facility commands.
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
local Defun = eval.Defun


Defun ("start_kbd_macro",
  {},
[[
Record subsequent keyboard input, defining a keyboard macro.
The commands are recorded even as they are executed.
Use @kbd{C-x )} to finish recording and make the macro available.
]],
  true,
  function ()
    if thisflag.defining_macro then
      minibuf_error ('Already defining a keyboard macro')
      return false
    end

    if cur_mp ~= nil then
      cancel_kbd_macro ()
    end

    minibuf_write ('Defining keyboard macro...')

    thisflag.defining_macro = true
    cur_mp = {}
  end
)


Defun ("end_kbd_macro",
  {},
[[
Finish defining a keyboard macro.
The definition was started by @kbd{C-x (}.
The macro is now available for use via @kbd{C-x e}.
]],
  true,
  function ()
    if not thisflag.defining_macro then
      minibuf_error ('Not defining a keyboard macro')
      return false
    end

    thisflag.defining_macro = false
  end
)


Defun ("call_last_kbd_macro",
  {},
[[
Call the last keyboard macro that you defined with @kbd{C-x (}.
A prefix argument serves as a repeat count.
]],
  true,
  function ()
    if cur_mp == nil then
      minibuf_error ('No kbd macro has been defined')
      return false
    end

    -- FIXME: Call execute_kbd_macro (needs a way to reverse keystrtovec)
    macro_keys = cur_mp
    execute_with_uniarg (true, current_prefix_arg, call_macro)
  end
)


Defun ("execute_kbd_macro",
  {"string"},
[[
Execute macro as string of editor command characters.
]],
  false,
  function (keystr)
    local keys = keystrtovec (keystr)
    if keys ~= nil then
      macro_keys = keys
      execute_with_uniarg (true, current_prefix_arg, call_macro)
      return true
    end
  end
)
