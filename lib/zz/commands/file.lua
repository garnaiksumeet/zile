-- Disk file handling
--
-- Copyright (c) 2009-2014 Free Software Foundation, Inc.
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

local FileString = require "zile.FileString"

local eval = require "zz.eval"
local Defun, zz = eval.Defun, eval.sandbox


Defun ("find_file",
[[
Edit file @i{filename}.
Switch to a buffer visiting file @i{filename},
creating one if none already exists.
]],
  true,
  function (filename)
    local ok = false

    if not filename then
      filename = minibuf_read_filename ('Find file: ', cur_bp.dir)
    end

    if not filename then
      ok = keyboard_quit ()
    elseif filename ~= '' then
      ok = find_file (filename)
    end

    return ok
  end
)


Defun ("find_file_read_only",
[[
Edit file @i{filename} but don't allow changes.
Like `find_file' but marks buffer as read-only.
Use @kbd{M-x toggle_read_only} to permit editing.
]],
  true,
  function (filename)
    local ok = zz.find_file (filename)
    if ok then
      cur_bp.readonly = true
    end
  end
)


Defun ("find_alternate_file",
[[
Find the file specified by the user, select its buffer, kill previous buffer.
If the current buffer now contains an empty file that you just visited
(presumably by mistake), use this command to visit the file you really want.
]],
  true,
  function ()
    local buf = cur_bp.filename
    local base, ms, as

    if not buf then
      buf = cur_bp.dir
    else
      base = posix.basename (buf)
    end
    ms = minibuf_read_filename ('Find alternate: ', buf, base)

    local ok = false
    if not ms then
      ok = keyboard_quit ()
    elseif ms ~= '' and check_modified_buffer (cur_bp ()) then
      kill_buffer (cur_bp)
      ok = find_file (ms)
    end

    return ok
  end
)


Defun ("insert_file",
[[
Insert contents of file FILENAME into buffer after point.
Set mark after the inserted text.
]],
  true,
  function (file)
    local ok = true

    if warn_if_readonly_buffer () then
      return false
    end

    if not file then
      file = minibuf_read_filename ('Insert file: ', cur_bp.dir)
      if not file then
        ok = keyboard_quit ()
      end
    end

    if not file or file == '' then
      ok = false
    end

    if ok then
      local s = io.slurp (file)
      if s then
        insert_estr (FileString (s))
        zz.set_mark_command ()
      else
        ok = minibuf_error ('%s: %s', file, posix.errno ())
      end
    end

    return ok
  end
)


Defun ("save_buffer",
[[
Save current buffer in visited file if modified.  By default, makes the
previous version into a backup file if this is the first save.
]],
  true,
  function ()
    return save_buffer (cur_bp)
  end
)


Defun ("write_file",
[[
Write current buffer into file @i{filename}.
This makes the buffer visit that file, and marks it as not modified.

Interactively, confirmation is required unless you supply a prefix argument.
]],
  true,
  function (filename)
    return write_buffer (cur_bp, filename == nil,
                         command.is_interactive () and not lastflag.set_uniarg,
                         filename, 'Write file: ')
  end
)


Defun ("save_some_buffers",
[[
Save some modified file-visiting buffers.  Asks user about each one.
]],
  true,
  function ()
    return save_some_buffers ()
  end
)


Defun ("save_buffers_kill_zz",
[[
Offer to save each buffer, then kill this process.
]],
  true,
  function ()
    if not save_some_buffers () then
      return false
    end

    for _, bp in ipairs (buffers) do
      if bp.modified and not bp.needname then
        while true do
          local ans = minibuf_read_yesno ('Modified buffers exist; exit anyway? (yes or no) ')
          if ans == nil then
            return keyboard_quit ()
          elseif not ans then
            return false
          end
          break -- We have found a modified buffer, so stop.
        end
      end
    end

    thisflag.quit = true
  end
)


Defun ("cd",
[[
Make DIR become the current buffer's default directory.
]],
  true,
  function (dir)
    if not dir and command.is_interactive () then
      dir = minibuf_read_filename ('Change default directory: ', cur_bp.dir)
    end

    if not dir then
      return keyboard_quit ()
    end

    if dir ~= '' then
      local st = posix.stat (dir)
      if not st or not st.type == 'directory' then
        minibuf_error (string.format ([[`%s' is not a directory]], dir))
      elseif posix.chdir (dir) == -1 then
        minibuf_write (string.format ('%s: %s', dir, posix.errno ()))
      else
        cur_bp.dir = dir
        return true
      end
    end
  end
)


Defun ("insert_buffer",
[[
Insert after point the contents of BUFFER.
Puts mark after the inserted text.
]],
  true,
  function (buffer)
    local ok = true

    local def_bp = buffers[#buffers]
    for i = 2, #buffers do
      if buffers[i] == cur_bp then
        def_bp = buffers[i - 1]
        break
      end
    end

    if warn_if_readonly_buffer () then
      return false
    end

    if not buffer then
      local cp = make_buffer_completion ()
      buffer = minibuf_read (string.format ('Insert buffer (default %s): ', def_bp.name),
                             '', cp, buffer_name_history)
      if not buffer then
        ok = keyboard_quit ()
      end
    end

    if ok then
      local bp

      if buffer and buffer ~= '' then
        bp = get_buffer (buffer)
        if not bp then
          ok = minibuf_error (string.format ([[Buffer `%s' not found]], buffer))
        end
      else
        bp = def_bp
      end

      if ok then
        insert_buffer (bp)
        zz.set_mark_command ()
      end
    end

    return ok
  end
)
