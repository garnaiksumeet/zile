-- Zz user commands
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

local Defun = eval.Defun

Defun ("beginning_of_line",
       {},
[[
Move point to beginning of current line.
]],
  true,
  beginning_of_line
)

Defun ("end_of_line",
       {},
[[
Move point to end of current line.
]],
  true,
  end_of_line
)

Defun ("backward_char",
       {"number"},
[[
Move point left N characters (right if N is negative).
On attempt to pass beginning or end_of_buffer, stop and signal error.
]],
  true,
  function (n)
    local ok = move_char (-(n or 1))
    if not ok then
      minibuf_error ("Beginning of buffer")
    end
    return ok
  end
)

Defun ("forward_char",
       {"number"},
[[
Move point right N characters (left if N is negative).
On reaching end_of_buffer, stop and signal error.
]],
  true,
  function (n)
    local ok = move_char (n or 1)
    if not ok then
      minibuf_error ("End of buffer")
    end
    return ok
  end
)

Defun ("goto_char",
       {"number"},
[[
Set point to @i{position}, a number.
Beginning of buffer is position 1.
]],
  true,
  function (n)
    if not n then
      n = minibuf_read_number ("Goto char: ")
    end

    return type (n) == "number" and goto_offset (math.min (get_buffer_size (cur_bp) + 1, math.max (n, 1)))
  end
)

Defun ("goto_line",
       {"number"},
[[
Goto @i{line}, counting from line 1 at beginning_of_buffer.
]],
  true,
  function (n)
    n = n or current_prefix_arg
    if not n and command.is_interactive () then
      n = minibuf_read_number ("Goto line: ")
    end

    if type (n) == "number" then
      move_line ((math.max (n, 1) - 1) - offset_to_line (cur_bp, get_buffer_pt (cur_bp)))
      beginning_of_line ()
    else
      return false
    end
  end
)

Defun ("previous_line",
       {"number"},
[[
Move cursor vertically up one line.
If there is no character in the target line exactly over the current column,
the cursor is positioned after the character in that line which spans this
column, or at the end of the line if it is not long enough.
]],
  true,
  function (n)
    return move_line (-(n or current_prefix_arg or 1))
  end
)

Defun ("next_line",
       {"number"},
[[
Move cursor vertically down one line.
If there is no character in the target line exactly under the current column,
the cursor is positioned after the character in that line which spans this
column, or at the end of the line if it is not long enough.
]],
  true,
  function (n)
    return move_line (n or current_prefix_arg or 1)
  end
)

Defun ("beginning_of_buffer",
       {},
[[
Move point to the beginning of the buffer; leave mark at previous position.
]],
  true,
  function ()
    goto_offset (1)
  end
)

Defun ("end_of_buffer",
       {},
[[
Move point to the end of the buffer; leave mark at previous position.
]],
  true,
  function ()
    goto_offset (get_buffer_size (cur_bp) + 1)
  end
)

Defun ("scroll_down",
       {"number"},
[[
Scroll text of current window downward near full screen.
]],
  true,
  function (n)
    return execute_with_uniarg (false, n or 1, scroll_down, scroll_up)
  end
)

Defun ("scroll_up",
       {"number"},
[[
Scroll text of current window upward near full screen.
]],
  true,
  function (n)
    return execute_with_uniarg (false, n or 1, scroll_up, scroll_down)
  end
)

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
    local name = minibuf_read_function_name ("Where is command: ")

    if name and eval.function_exists (name) then
      local g = { f = name, bindings = "" }

      walk_bindings (root_bindings, gather_bindings, g)

      if #g.bindings == 0 then
        minibuf_write (name .. " is not on any key")
      else
        minibuf_write (string.format ("%s is on %s", name, g.bindings))
      end
      return true
    end
  end
)

local function print_binding (key, func)
  insert_string (string.format ("%-15s %s\n", key, func))
end

local function write_bindings_list (key, binding)
  insert_string ("Key translations:\n")
  insert_string (string.format ("%-15s %s\n", "key", "binding"))
  insert_string (string.format ("%-15s %s\n", "---", "-------"))

  walk_bindings (root_bindings, print_binding)
end

Defun ("describe_bindings",
       {},
[[
Show a list of all defined keys, and their definitions.
]],
  true,
  function ()
    write_temp_buffer ("*Help*", true, write_bindings_list)
    return true
  end
)

Defun ("global_set_key",
       {"string", "string"},
[[
Bind a command to a key sequence.
Read key sequence and function name, and bind the function to the key
sequence.
]],
  true,
  function (keystr, name)
    local keys = prompt_key_sequence ("Set key globally", keystr)

    if keystr == nil then
      keystr = tostring (keys)
    end

    if not name then
      name = minibuf_read_function_name (string.format ("Set key %s to command: ", keystr))
      if not name then
        return
      end
    end

    if not eval.function_exists (name) then -- Possible if called non-interactively
      minibuf_error (string.format ("No such function `%s'", name))
      return
    end

io.stderr:write ("global_set_key: "..tostring(keys).." = "..name.."\n")
    root_bindings[keys] = name

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
    local keys = prompt_key_sequence ("Unset key globally", keystr)

    if keystr == nil then
      keystr = tostring (keys)
    end

    root_bindings[keys] = nil

    return true
  end
)

Defun ("kill_buffer",
       {"string"},
[[
Kill buffer BUFFER.
With a nil argument, kill the current buffer.
]],
  true,
  function (buffer)
    local ok = true

    if not buffer then
      local cp = make_buffer_completion ()
      buffer = minibuf_read (string.format ("Kill buffer (default %s): ", cur_bp.name),
                             "", cp, buffer_name_history)
      if not buffer then
        ok = keyboard_quit ()
      end
    end

    local bp
    if buffer and buffer ~= "" then
      bp = find_buffer (buffer)
      if not bp then
        minibuf_error (string.format ("Buffer `%s' not found", buffer))
        ok = false
      end
    else
      bp = cur_bp
    end

    if ok then
      if not check_modified_buffer (bp) then
        ok = false
      else
        kill_buffer (bp)
      end
    end

    return ok
  end
)

Defun ("switch_to_buffer",
       {"string"},
[[
Select buffer @i{buffer} in the current window.
]],
  true,
  function (buffer)
    local ok = true
    local bp = buffer_next (cur_bp)

    if not buffer then
      local cp = make_buffer_completion ()
      buffer = minibuf_read (string.format ("Switch to buffer (default %s): ", bp.name),
                             "", cp, buffer_name_history)

      if not buffer then
        ok = keyboard_quit ()
      end
    end

    if ok then
      if buffer and buffer ~= "" then
        bp = find_buffer (buffer)
        if not bp then
          bp = buffer_new ()
          bp.name = buffer
          bp.needname = true
          bp.nosave = true
        end
      end

      switch_to_buffer (bp)
    end

    return ok
  end
)

Defun ("find_file",
       {"string"},
[[
Edit file @i{filename}.
Switch to a buffer visiting file @i{filename},
creating one if none already exists.
]],
  true,
  function (filename)
    local ok = false

    if not filename then
      filename = minibuf_read_filename ("Find file: ", cur_bp.dir)
    end

    if not filename then
      ok = keyboard_quit ()
    elseif filename ~= "" then
      ok = find_file (filename)
    end

    return ok
  end
)

Defun ("find_file_read_only",
       {"string"},
[[
Edit file @i{filename} but don't allow changes.
Like `find_file' but marks buffer as read-only.
Use @kbd{M-x toggle_read_only} to permit editing.
]],
  true,
  function (filename)
    local ok = eval.execute_function ("find_file", filename)
    if ok then
      cur_bp.readonly = true
    end
  end
)

Defun ("find_alternate_file",
       {},
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
    ms = minibuf_read_filename ("Find alternate: ", buf, base)

    local ok = false
    if not ms then
      ok = keyboard_quit ()
    elseif ms ~= "" and check_modified_buffer (cur_bp ()) then
      kill_buffer (cur_bp)
      ok = find_file (ms)
    end

    return ok
  end
)

Defun ("insert_file",
       {"string"},
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
      file = minibuf_read_filename ("Insert file: ", cur_bp.dir)
      if not file then
        ok = keyboard_quit ()
      end
    end

    if not file or file == "" then
      ok = false
    end

    if ok then
      local s = io.slurp (file)
      if s then
        insert_estr (EStr (s))
        eval.execute_function ("set_mark_command")
      else
        ok = minibuf_error ("%s: %s", file, posix.errno ())
      end
    end

    return ok
  end
)

Defun ("save_buffer",
       {},
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
       {},
[[
Write current buffer into file @i{filename}.
This makes the buffer visit that file, and marks it as not modified.

Interactively, confirmation is required unless you supply a prefix argument.
]],
  true,
  function ()
    return write_buffer (cur_bp, true,
                         command.is_interactive () and not lastflag.set_uniarg,
                         nil, "Write file: ")
  end
)

Defun ("save_some_buffers",
       {},
[[
Save some modified file-visiting buffers.  Asks user about each one.
]],
  true,
  function ()
    return save_some_buffers ()
  end
)

Defun ("save_buffers_kill_emacs",
       {},
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
          local ans = minibuf_read_yesno ("Modified buffers exist; exit anyway? (yes or no) ")
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
       {"string"},
[[
Make DIR become the current buffer's default directory.
]],
  true,
  function (dir)
    if not dir and command.is_interactive () then
      dir = minibuf_read_filename ("Change default directory: ", cur_bp.dir)
    end

    if not dir then
      return keyboard_quit ()
    end

    if dir ~= "" then
      local st = posix.stat (dir)
      if not st or not st.type == "directory" then
        minibuf_error (string.format ("`%s' is not a directory", dir))
      elseif posix.chdir (dir) == -1 then
        minibuf_write (string.format ("%s: %s", dir, posix.errno ()))
      else
        cur_bp.dir = dir
        return true
      end
    end
  end
)

Defun ("insert_buffer",
       {"string"},
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
      buffer = minibuf_read (string.format ("Insert buffer (default %s): ", def_bp.name),
                             "", cp, buffer_name_history)
      if not buffer then
        ok = keyboard_quit ()
      end
    end

    if ok then
      local bp

      if buffer and buffer ~= "" then
        bp = find_buffer (buffer)
        if not bp then
          ok = minibuf_error (string.format ("Buffer `%s' not found", buffer))
        end
      else
        bp = def_bp
      end

      if ok then
        insert_buffer (bp)
        eval.execute_function ("set_mark_command")
      end
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

Defun ("suspend_emacs",
       {},
[[
Stop and return to superior process.
]],
  true,
  suspend
)

Defun ("toggle_read_only",
       {},
[[
Change whether this buffer is visiting its file read-only.
]],
  true,
  function ()
    cur_bp.readonly = not cur_bp.readonly
  end
)

Defun ("auto_fill_mode",
       {},
[[
Toggle Auto Fill mode.
In Auto Fill mode, inserting a space at a column beyond `fill-column'
automatically breaks the line at a previous space.
]],
  true,
  function ()
    cur_bp.autofill = not cur_bp.autofill
  end
)

Defun ("exchange_point_and_mark",
       {},
[[
Put the mark where point is now, and point where the mark is now.
]],
  true,
  function ()
    if not cur_bp.mark then
      return minibuf_error ("No mark set in this buffer")
    end

    local tmp = get_buffer_pt (cur_bp)
    goto_offset (cur_bp.mark.o)
    cur_bp.mark.o = tmp
    activate_mark ()
    thisflag.need_resync = true
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
      local as = ""
      local key = do_binding_completion (table.concat (keys, " "))

      -- Cancelled.
      if key == keycode "\\C-g" then
        ok = keyboard_quit ()
        break
      -- Digit pressed.
      elseif string.match (string.char (key.key), "%d") then
        local digit = key.key - string.byte ('0')
        thisflag.uniarg_empty = false

        if key.META then
          as = "ESC "
        end

        as = as .. string.format ("%d", digit)

        if i == 0 then
          arg = digit
        else
          arg = arg * 10 + digit
        end

        i = i + 1
      elseif key == keycode "\\C-u" then
        as = as .. "C-u"
        if i == 0 then
          arg = arg * 4
        else
          break
        end
      elseif key == keycode "\\M--" and i == 0 then
        if sgn > 0 then
          sgn = -sgn
          as = as .. "-"
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

local function write_buffers_list (old_wp)
  -- FIXME: Underline next_line properly.
  insert_string ("CRM Buffer                Size  Mode             File\n")
  insert_string ("--- ------                ----  ----             ----\n")

  -- Rotate buffer list to get current buffer at head.
  local bufs = table.clone (buffers)
  for i = #buffers, 1, -1 do
    if buffers[i] == old_wp.bp then
      break
    end
    table.insert (bufs, 1, table.remove (bufs))
  end

  -- Print buffers.
  for _, bp in ripairs (bufs) do
    -- Print all buffers whose names don't start with space except
    -- this one (the *Buffer List*).
    if cur_bp ~= bp and bp.name[1] ~= ' ' then
      insert_string (string.format ("%s%s%s %-19s %6u  %-17s",
                                    old_wp.bp == bp and '.' or ' ',
                                    bp.readonly and '%' or ' ',
                                    bp.modified and '*' or ' ',
                                    bp.name, get_buffer_size (bp), "Fundamental"))
      if bp.filename then
        insert_string (compact_path (bp.filename))
      end
      insert_newline ()
    end
  end
end

Defun ("list_buffers",
       {},
[[
Display a list of names of existing buffers.
The list is displayed in a buffer named `*Buffer List*'.

The C column has a `.' for the buffer from which you came.
The R column has a `%' if the buffer is read-only.
The M column has a `*' if it is modified.
After this come the buffer name, its size in characters,
its major mode, and the visited file name (if any).
]],
  true,
  function ()
    write_temp_buffer ("*Buffer List*", true, write_buffers_list, cur_wp)
  end
)

Defun ("set_mark",
       {},
[[
Set this buffer's mark to point.
]],
  false,
  function ()
    set_mark ()
    activate_mark ()
  end
)

Defun ("set_mark_command",
       {},
[[
Set the mark where point is.
]],
  true,
  function ()
    eval.execute_function ("set_mark")
    minibuf_write ("Mark set")
  end
)

Defun ("set_fill_column",
       {"number"},
[[
Set `fill-column' to specified argument.
Use C-u followed by a number to specify a column.
Just C-u as argument means to use the current column.
]],
  true,
  function (n)
    if not n and command.is_interactive () then
      local o = get_buffer_pt (cur_bp) - get_buffer_line_o (cur_bp)
      if lastflag.set_uniarg then
        n = current_prefix_arg
      else
        n = minibuf_read_number (string.format ("Set fill-column to (default %d): ", o))
        if not n then -- cancelled
          return false
        elseif n == "" then
          n = o
        end
      end
    end

    if not n then
      return minibuf_error ("set_fill_column requires an explicit argument")
    end

    minibuf_write (string.format ("Fill column set to %d (was %d)", n, get_variable_number ("fill-column")))
    set_variable ("fill-column", tostring (n))
    return true
  end
)

Defun ("quoted_insert",
       {},
[[
Read next input character and insert it.
This is useful for inserting control characters.
]],
  true,
  function ()
    minibuf_write ("C-q-")
    insert_char (string.char (bit32.band (getkey_unfiltered (GETKEY_DEFAULT), 0xff)))
    minibuf_clear ()
  end
)

Defun ("fill_paragraph",
       {},
[[
Fill paragraph at or after point.
]],
  true,
  function ()
    local m = point_marker ()

    undo_start_sequence ()

    eval.execute_function ("forward_paragraph")
    if is_empty_line () then
      previous_line ()
    end
    local m_end = point_marker ()

    eval.execute_function ("backward_paragraph")
    if is_empty_line () then -- Move to next_line if between two paragraphs.
      next_line ()
    end

    while buffer_end_of_line (cur_bp, get_buffer_pt (cur_bp)) < m_end.o do
      end_of_line ()
      delete_char ()
      eval.execute_function ("just_one_space")
    end
    unchain_marker (m_end)

    end_of_line ()
    while get_goalc () > get_variable_number ("fill-column") + 1 and fill_break_line () do end

    goto_offset (m.o)
    unchain_marker (m)

    undo_end_sequence ()
  end
)

Defun ("shell_command",
       {"string", "boolean"},
[[
Execute string @i{command} in inferior shell; display output, if any.
With prefix argument, insert the command's output at point.

Command is executed synchronously.  The output appears in the buffer
`*Shell Command Output*'.  If the output is short enough to display
in the echo area, it is shown there, but it is nonetheless available
in buffer `*Shell Command Output*' even though that buffer is not
automatically displayed.

The optional second argument @i{output-buffer}, if non-nil,
says to insert the output in the current buffer.
]],
  true,
  function (cmd, insert)
    if not insert then
      insert = lastflag.set_uniarg
    end
    if not cmd then
      cmd = minibuf_read_shell_command ()
    end

    if cmd then
      return pipe_command (cmd, "/dev/null", insert, false)
    end
    return true
  end
)

-- The `start' and `end' arguments are fake, hence their string type,
-- so they can be ignored.
Defun ("shell_command_on_region",
       {"string", "string", "string", "boolean"},
[[
Execute string command in inferior shell with region as input.
Normally display output (if any) in temp buffer `*Shell Command Output*'
Prefix arg means replace the region with it.  Return the exit code of
command.

If the command generates output, the output may be displayed
in the echo area or in a buffer.
If the output is short enough to display in the echo area, it is shown
there.  Otherwise it is displayed in the buffer `*Shell Command Output*'.
The output is available in that buffer in both cases.
]],
  true,
  function (start, finish, cmd, insert)
    local ok = true

    if not cmd then
      cmd = minibuf_read_shell_command ()
    end
    if not insert then
      insert = lastflag.set_uniarg
    end

    if cmd then
      local rp = calculate_the_region ()

      if not rp then
        ok = false
      else
        local tempfile = os.tmpname ()
        local fd = io.open (tempfile, "w")

        if not fd then
          ok = minibuf_error ("Cannot open temporary file")
        else
          local written, err = fd:write (tostring (get_region ()))

          if not written then
            ok = minibuf_error ("Error writing to temporary file: " .. err)
          else
            ok = pipe_command (cmd, tempfile, insert, true)
          end

          fd:close ()
          os.remove (tempfile)
        end
      end
    end
    return ok
  end
)

Defun ("delete_region",
       {},
[[
Delete the text between point and mark.
]],
  true,
  function ()
    return delete_region (calculate_the_region ())
  end
)

Defun ("delete_blank_lines",
       {},
[[
On blank line, delete all surrounding blank lines, leaving just one.
On isolated blank line, delete that one.
On nonblank line, delete any immediately following blank lines.
]],
  true,
  function ()
    local m = point_marker ()
    local r = region_new (get_buffer_line_o (cur_bp), get_buffer_line_o (cur_bp))

    undo_start_sequence ()

    -- Find following blank lines.
    if move_line (1) and is_blank_line () then
      r.start = get_buffer_pt (cur_bp)
      repeat
        r.finish = buffer_next_line (cur_bp, get_buffer_pt (cur_bp))
      until not move_line (1) or not is_blank_line ()
    end
    goto_offset (m.o)

    -- If this line is blank, find any preceding blank lines.
    local singleblank = true
    if is_blank_line () then
      r.finish = math.max (r.finish, buffer_next_line (cur_bp, get_buffer_pt (cur_bp) or math.huge))
      repeat
        r.start = get_buffer_line_o (cur_bp)
      until not move_line (-1) or not is_blank_line ()

      goto_offset (m.o)
      if r.start ~= get_buffer_line_o (cur_bp) or r.finish > buffer_next_line (cur_bp, get_buffer_pt (cur_bp)) then
        singleblank = false
      end
      r.finish = math.min (r.finish, get_buffer_size (cur_bp))
    end

    -- If we are deleting to EOB, need to fudge extra line.
    local at_eob = r.finish == get_buffer_size (cur_bp) and r.start > 0
    if at_eob then
      r.start = r.start - #get_buffer_eol (cur_bp)
    end

    -- Delete any blank lines found.
    if r.start < r.finish then
      delete_region (r)
    end

    -- If we found more than one blank line, leave one.
    if not singleblank then
      if not at_eob then
        intercalate_newline ()
      else
        insert_newline ()
      end
    end

    undo_end_sequence ()

    unchain_marker (m)
    deactivate_mark ()
  end
)

Defun ("forward_line",
       {"number"},
[[
Move N lines forward (backward if N is negative).
Precisely, if point is on line I, move to the start of line I + N.
]],
  true,
  function (n)
    n = n or current_prefix_arg or 1
    if n ~= 0 then
      beginning_of_line ()
      return move_line (n)
    end
    return false
  end
)

local function move_paragraph (uniarg, forward, backward, line_extremum)
  if uniarg < 0 then
    uniarg = -uniarg
    forward = backward
  end

  for i = uniarg, 1, -1 do
    repeat until not is_empty_line () or not forward ()
    repeat until is_empty_line () or not forward ()
  end

  if is_empty_line () then
    beginning_of_line ()
  else
    line_extremum ()
  end
  return true
end

Defun ("backward_paragraph",
       {"number"},
[[
Move backward to start of paragraph.  With argument N, do it N times.
]],
  true,
  function (n)
    return move_paragraph (n or 1, previous_line, next_line, beginning_of_line)
  end
)

Defun ("forward_paragraph",
       {"number"},
[[
Move forward to end of paragraph.  With argument N, do it N times.
]],
  true,
  function (n)
    return move_paragraph (n or 1, next_line, previous_line, end_of_line)
  end
)

Defun ("forward_sexp",
       {"number"},
[[
Move forward across one balanced expression (sexp).
With argument, do it that many times.  Negative arg -N means
move backward across N balanced expressions.
]],
  true,
  function (n)
    return move_with_uniarg (n or 1, move_sexp)
  end
)

Defun ("backward_sexp",
       {"number"},
[[
Move backward across one balanced expression (sexp).
With argument, do it that many times.  Negative arg -N means
move forward across N balanced expressions.
]],
  true,
  function (n)
    return move_with_uniarg (-(n or 1), move_sexp)
  end
)

local function mark (uniarg, func)
  eval.execute_function ("set_mark")
  local ret = eval.execute_function (func, uniarg)
  if ret then
    eval.execute_function ("exchange_point_and_mark")
  end
  return ret
end

Defun ("mark_word",
       {"number"},
[[
Set mark argument words away from point.
]],
  true,
  function (n)
    return mark (n, "forward_word")
  end
)

Defun ("mark_sexp",
       {"number"},
[[
Set mark @i{arg} sexps from point.
The place mark goes is the same place @kbd{C-M-f} would
move to with the same argument.
]],
  true,
  function (n)
    return mark (n, "forward_sexp")
  end
)

Defun ("mark_paragraph",
       {},
[[
Put point at beginning of this paragraph, mark at end.
The paragraph marked is the one that contains point or follows point.
]],
  true,
  function ()
    if command.was_labelled (":mark_paragraph") then
      eval.execute_function ("exchange_point_and_mark")
      eval.execute_function ("forward_paragraph")
      eval.execute_function ("exchange_point_and_mark")
    else
      eval.execute_function ("forward_paragraph")
      eval.execute_function ("set_mark")
      eval.execute_function ("backward_paragraph")
    end

    command.attach_label (":mark_paragraph")
  end
)

Defun ("mark_whole_buffer",
       {},
[[
Put point at beginning and mark at end_of_buffer.
]],
  true,
  function ()
    goto_offset (get_buffer_size (cur_bp) + 1)
    eval.execute_function ("set_mark_command")
    goto_offset (1)
  end
)

Defun ("back_to_indentation",
       {},
[[
Move point to the first non-whitespace character on this line.
]],
  true,
  function ()
    goto_offset (get_buffer_line_o (cur_bp))
    while not eolp () and following_char ():match ("%s") do
      move_char (1)
    end
  end
)

Defun ("forward_word",
       {"number"},
[[
Move point forward one word (backward if the argument is negative).
With argument, do this that many times.
]],
  true,
  function (n)
    return move_with_uniarg (n or 1, move_word)
  end
)

Defun ("backward_word",
       {"number"},
[[
Move backward until encountering the end of a word (forward if the
argument is negative).
With argument, do this that many times.
]],
  true,
  function (n)
    return move_with_uniarg (-(n or 1), move_word)
  end
)

Defun ("downcase_word",
       {"number"},
[[
Convert following word (or @i{arg} words) to lower case, moving over.
]],
  true,
  function (arg)
    return execute_with_uniarg (true, arg, function () return setcase_word ("lower") end)
  end
)

Defun ("upcase_word",
       {"number"},
[[
Convert following word (or @i{arg} words) to upper case, moving over.
]],
  true,
  function (arg)
    return execute_with_uniarg (true, arg, function () return setcase_word ("upper") end)
  end
)

Defun ("capitalize_word",
       {"number"},
[[
Capitalize the following word (or @i{arg} words), moving over.
This gives the word(s) a first character in upper case
and the rest lower case.
]],
  true,
  function (arg)
    return execute_with_uniarg (true, arg, function () return setcase_word ("capitalized") end)
  end
)

Defun ("upcase_region",
       {},
[[
Convert the region to upper case.
]],
  true,
  function ()
    return setcase_region (string.upper)
  end
)

Defun ("downcase_region",
       {},
[[
Convert the region to lower case.
]],
  true,
  function ()
    return setcase_region (string.lower)
  end
)

Defun ("transpose_chars",
       {"number"},
[[
Interchange characters around point, moving forward one character.
With prefix arg ARG, effect is to take character before point
and drag it forward past ARG other characters (backward if ARG negative).
If no argument and at end_of_line, the previous two chars are exchanged.
]],
  true,
  function (n)
    return transpose (n or 1, move_char)
  end
)

Defun ("transpose_words",
       {"number"},
[[
Interchange words around point, leaving point at end of them.
With prefix arg ARG, effect is to take word before or around point
and drag it forward past ARG other words (backward if ARG negative).
If ARG is zero, the words around or after point and around or after mark
are interchanged.
]],
  true,
  function (n)
    return transpose (n or 1, move_word)
  end
)

Defun ("transpose_sexps",
       {"number"},
[[
Like @kbd{M-x transpose_words} but applies to sexps.
]],
  true,
  function (n)
    return transpose (n or 1, move_sexp)
  end
)

Defun ("transpose_lines",
       {"number"},
[[
Exchange current line and previous_line, leaving point after both.
With argument ARG, takes previous_line and moves it past ARG lines.
With argument 0, interchanges line point is in with line mark is in.
]],
  true,
  function (n)
    return transpose (n or 1, move_line)
  end
)

local function write_function_description (name, doc)
  insert_string (string.format ("%s is %s built-in function in `Lua source code'.\n\n%s",
                                name,
                                eval.get_function_interactive (name) and "an interactive" or "a",
                                doc))
end

Defun ("describe_function",
       {"string"},
[[
Display the full documentation of a function.
]],
  true,
  function (func)
    if not func then
      func = minibuf_read_function_name ("Describe function: ")
      if not func then
        return false
      end
    end

    local doc = eval.get_function_doc (func)
    if not doc then
      return false
    else
      write_temp_buffer ("*Help*", true, write_function_description, func, doc)
    end

    return true
  end
)

local function write_key_description (name, doc, binding)
  local _interactive = eval.get_function_interactive (name)
  assert (_interactive ~= nil)

  insert_string (string.format ("%s runs the command %s, which is %s built-in\n" ..
                                "function in `Lua source code'.\n\n%s",
                              binding, name,
                              _interactive and "an interactive" or "a",
                              doc))
end

Defun ("describe_key",
       {"string"},
[[
Display documentation of the command invoked by a key sequence.
]],
  true,
  function (keystr)
    local name, binding, keys
    if keystr then
      keys = keystrtovec (keystr)
      if not keys then
        return false
      end
      name = get_function_by_keys (keys)
      binding = tostring (keys)
    else
      minibuf_write ("Describe key:")
      keys = get_key_sequence ()
      name = get_function_by_keys (keys)
      binding = tostring (keys)

      if not name then
        return minibuf_error (binding .. " is undefined")
      end
    end

    minibuf_write (string.format ("%s runs the command `%s'", binding, name))

    local doc = eval.get_function_doc (name)
    if not doc then
      return false
    end
    write_temp_buffer ("*Help*", true, write_key_description, name, doc, binding)

    return true
  end
)

local function write_variable_description (name, curval, doc)
  insert_string (string.format ("%s is a variable defined in `Lua source code'.\n\n" ..
                                "Its value is %s\n\n%s",
                              name, curval, doc))
end

Defun ("describe_variable",
       {"string"},
[[
Display the full documentation of a variable.
]],
  true,
  function (name)
    local ok = true

    if not name then
      name = minibuf_read_variable_name ("Describe variable: ")
    end

    if not name then
      ok = false
    else
      local doc = main_vars[name].doc

      if not doc then
        ok = false
      else
        write_temp_buffer ("*Help*", true,
                           write_variable_description,
                           name, get_variable (name), doc)
      end
    end
    return ok
  end
)

local function kill_text (uniarg, mark_func)
  maybe_free_kill_ring ()

  if warn_if_readonly_buffer () then
    return false
  end

  push_mark ()
  undo_start_sequence ()
  eval.execute_function (mark_func, uniarg)
  eval.execute_function ("kill_region")
  undo_end_sequence ()
  pop_mark ()
  minibuf_clear () -- Erase "Set mark" message.

  return true
end

Defun ("kill_word",
       {"number"},
[[
Kill characters forward until encountering the end of a word.
With argument @i{arg}, do this that many times.
]],
  true,
  function (arg)
    return kill_text (arg, "mark_word")
  end
)

Defun ("backward_kill_word",
       {"number"},
[[
Kill characters backward until encountering the end of a word.
With argument @i{arg}, do this that many times.
]],
  true,
  function (arg)
    return kill_text (-(arg or 1), "mark_word")
  end
)

Defun ("kill_sexp",
       {"number"},
[[
Kill the sexp (balanced expression) following the cursor.
With @i{arg}, kill that many sexps after the cursor.
Negative arg -N means kill N sexps before the cursor.
]],
  true,
  function (arg)
    return kill_text (arg, "mark_sexp")
  end
)

Defun ("yank",
       {},
[[
Reinsert the last stretch of killed text.
More precisely, reinsert the stretch of killed text most recently
killed @i{or} yanked.  Put point at end, and set_mark at beginning.
]],
  true,
  function ()
    if killring_empty () then
      minibuf_error ("Kill ring is empty")
      return false
    end

    if warn_if_readonly_buffer () then
      return false
    end

    eval.execute_function ("set_mark_command")
    killring_yank ()
    deactivate_mark ()
  end
)

Defun ("kill_region",
       {},
[[
Kill between point and mark.
The text is deleted but saved in the kill ring.
The command @kbd{C-y} (yank) can retrieve it from there.
If the buffer is read-only, beep and refrain from deleting the text,
but put the text in the kill ring anyway.  This means that you can
use the killing commands to copy text from a read-only buffer.  If
the previous command was also a kill command, the text killed this
time appends to the text killed last time to make one entry in the
kill ring.
]],
  true,
  function ()
    local rp = calculate_the_region ()

    if rp then
      maybe_free_kill_ring ()
      kill_region (rp)
      return true
    end

    return false
  end
)

Defun ("copy_region_as_kill",
       {},
[[
Save the region as if killed, but don't kill it.
]],
  true,
  function ()
    local rp = calculate_the_region ()

    if rp then
      maybe_free_kill_ring ()
      copy_region (rp)
      return true
    end

    return false
  end
)

Defun ("kill_line",
       {"number"},
[[
Kill the rest of the current line; if no nonblanks there, kill thru newline.
With prefix argument @i{arg}, kill that many lines from point.
Negative arguments kill_lines backward.
With zero argument, kills the text before point on the current line.

If @samp{kill-whole-line} is non-nil, then this command kills the whole line
including its terminating newline, when used at the beginning of a line
with no argument.
]],
  true,
  function (arg)
    local ok = true

    maybe_free_kill_ring ()

    if not arg then
      ok = kill_line (bolp () and get_variable_bool ("kill-whole-line"))
    else
      undo_start_sequence ()
      if arg <= 0 then
        kill_to_bol ()
      end
      if arg ~= 0 and ok then
        ok = execute_with_uniarg (false, arg, kill_whole_line, kill_line_backward)
      end
      undo_end_sequence ()
    end

    deactivate_mark ()
    return ok
  end
)

Defun ("indent_for_tab_command",
       {},
[[
Indent line or insert a tab.
Depending on `tab-always-indent', either insert a tab or indent.
If initial point was within line's indentation, position after
the indentation.  Else stay at same point in text.
]],
  true,
  function ()
    if get_variable_bool ("tab-always-indent") then
      return insert_tab ()
    elseif (get_goalc () < previous_line_indent ()) then
      return eval.execute_function ("indent_relative")
    end
  end
)

Defun ("indent_relative",
       {},
[[
Space out to under next indent point in previous nonblank line.
An indent point is a non-whitespace character following whitespace.
The following line shows the indentation points in this line.
    ^         ^    ^     ^   ^           ^      ^  ^    ^
If the previous nonblank line has no indent points beyond the
column point starts at, `tab_to_tab_stop' is done instead, unless
this command is invoked with a numeric argument, in which case it
does nothing.
]],
  true,
  function ()
    local target_goalc = 0
    local cur_goalc = get_goalc ()
    local t = tab_width (cur_bp)
    local ok = false

    if warn_if_readonly_buffer () then
      return false
    end

    deactivate_mark ()

    -- If we're on the first line, set target to 0.
    if get_buffer_line_o (cur_bp) == 0 then
      target_goalc = 0
    else
      -- Find goalc in previous non-blank line.
      local m = point_marker ()

      previous_nonblank_goalc ()

      -- Now find the next blank char.
      if preceding_char () ~= '\t' or get_goalc () <= cur_goalc then
        while not eolp () and not following_char ():match ("%s") do
          move_char (1)
        end
      end

      -- Find next non-blank char.
      while not eolp () and following_char ():match ("%s") do
        move_char (1)
      end

      -- Target column.
      if not eolp () then
        target_goalc = get_goalc ()
      end
      goto_offset (m.o)
      unchain_marker (m)
    end

    -- Insert indentation.
    undo_start_sequence ()
    if target_goalc > 0 then
      -- If not at EOL on target line, insert spaces & tabs up to
      -- target_goalc; if already at EOL on target line, insert a tab.
      cur_goalc = get_goalc ()
      if cur_goalc < target_goalc then
        repeat
          if cur_goalc % t == 0 and cur_goalc + t <= target_goalc then
            ok = insert_tab ()
          else
            ok = insert_char (' ')
          end
          cur_goalc = get_goalc ()
        until not ok or cur_goalc >= target_goalc
      else
        ok = insert_tab ()
      end
    else
      ok = insert_tab ()
    end
    undo_end_sequence ()

    return ok
  end
)

Defun ("newline_and_indent",
       {},
[[
Insert a newline, then indent.
Indentation is done using the `indent_for_tab_command' function.
]],
  true,
  function ()
    local ok = false

    if warn_if_readonly_buffer () then
      return false
    end

    deactivate_mark ()

    undo_start_sequence ()
    if insert_newline () then
      local m = point_marker ()
      local pos

      -- Check where last non-blank goalc is.
      previous_nonblank_goalc ()
      pos = get_goalc ()
      local indent = pos > 0 or (not eolp () and following_char ():match ("%s"))
      goto_offset (m.o)
      unchain_marker (m)
      -- Only indent if we're in column > 0 or we're in column 0 and
      -- there is a space character there in the last non-blank line.
      if indent then
        eval.execute_function ("indent_for_tab_command")
      end
      ok = true
    end
    undo_end_sequence ()

    return ok
  end
)


Defun ("delete_char",
       {"number"},
[[
Delete the following @i{n} characters (previous if @i{n} is negative).
]],
  true,
  function (n)
    return execute_with_uniarg (true, n, delete_char, backward_delete_char)
  end
)

Defun ("backward_delete_char",
       {"number"},
[[
Delete the previous @i{n} characters (following if @i{n} is negative).
]],
  true,
  function (n)
    return execute_with_uniarg (true, n, backward_delete_char, delete_char)
  end
)

Defun ("delete_horizontal_space",
       {},
[[
Delete all spaces and tabs around point.
]],
  true,
  delete_horizontal_space
)

Defun ("just_one_space",
       {},
[[
Delete all spaces and tabs around point, leaving one space.
]],
  true,
  function ()
    undo_start_sequence ()
    delete_horizontal_space ()
    insert_char (' ')
    undo_end_sequence ()
  end
)

Defun ("tab_to_tab_stop",
       {"number"},
[[
Insert a tabulation at the current point position into the current
buffer.
]],
  true,
  function (n)
    return execute_with_uniarg (true, n, insert_tab)
  end
)

local function newline ()
  if cur_bp.autofill and get_goalc () > get_variable_number ("fill-column") then
    fill_break_line ()
  end
  return insert_newline ()
end

Defun ("newline",
       {"number"},
[[
Insert a newline at the current point position into
the current buffer.
]],
  true,
  function (n)
    return execute_with_uniarg (true, n, newline)
  end
)

Defun ("open_line",
       {"number"},
[[
Insert a newline and leave point before it.
]],
  true,
  function (n)
    return execute_with_uniarg (true, n, intercalate_newline)
  end
)

Defun ("insert",
       {"string"},
[[
Insert the argument at point.
]],
  false,
  function (arg)
    insert_string (arg)
  end
)

Defun ("load",
       {"string"},
[[
Execute a file of Lisp code named FILE.
]],
  true,
  function (file)
    if file then
      return eval.loadfile (file)
    end
  end
)

Defun ("execute_extended_command",
       {"number"},
[[
Read function name, then read its arguments and call it.
]],
  true,
  function (n)
    local msg = ""

    if lastflag.set_uniarg then
      if lastflag.uniarg_empty then
        msg = "C-u "
      else
        msg = string.format ("%d ", current_prefix_arg)
      end
    end
    msg = msg .. "M-x "

    local name = minibuf_read_function_name (msg)
    return name and eval.execute_function (name, n) or nil
  end
)

-- Read a function name from the minibuffer.
local functions_history = history_new ()
function minibuf_read_function_name (fmt)
  local cp = completion_new ()

  for name, func in eval.commands () do
    if func.interactive then
      table.insert (cp.completions, name)
    end
  end

  return minibuf_vread_completion (fmt, "", cp, functions_history,
                                   "No function name given",
                                   "Undefined function name `%s'")
end


Defun ("eval_buffer",
       {"string"},
[[
Execute the current buffer as Lisp code.

When called from a Lisp program (i.e., not interactively), this
function accepts an optional argument, the buffer to evaluate (nil
means use current buffer).
]],
  true,
  function (buffer)
    local bp = (buffer and buffer ~= "") and find_buffer (buffer) or cur_bp
    return eval.loadstring (get_buffer_pre_point (bp) .. get_buffer_post_point (bp))
  end
)

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
      minibuf_error ("Already defining a keyboard macro")
      return false
    end

    if cur_mp ~= nil then
      cancel_kbd_macro ()
    end

    minibuf_write ("Defining keyboard macro...")

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
      minibuf_error ("Not defining a keyboard macro")
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
      minibuf_error ("No kbd macro has been defined")
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

Defun ("recenter",
       {},
[[
Center point in selected window and redisplay frame.
]],
  true,
  interactive_recenter
)

Defun ("copy_to_register",
       {"number"},
[[
Copy region into register @i{register}.
]],
  true,
  function (reg)
    if not reg then
      minibuf_write ("Copy to register: ")
      reg = getkey_unfiltered (GETKEY_DEFAULT)
    end

    if reg == 7 then
      return keyboard_quit ()
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
      minibuf_write ("Insert register: ")
      reg = getkey_unfiltered (GETKEY_DEFAULT)
    end

    if reg == 7 then
      ok = keyboard_quit ()
    else
      minibuf_clear ()
      if register_isempty (reg) then
        minibuf_error ("Register does not contain text")
        ok = false
      else
        eval.execute_function ("set_mark_command")
	regnum = reg
        execute_with_uniarg (true, current_prefix_arg, insert_register)
        eval.execute_function ("exchange_point_and_mark")
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
    write_temp_buffer ("*Registers List*", true, write_registers_list)
  end
)

Defun ("search_forward",
       {"string"},
[[
Search forward from point for the user specified text.
]],
  true,
  function (pattern)
    return do_search (true, false, pattern)
  end
)

Defun ("search_backward",
       {"string"},
[[
Search backward from point for the user specified text.
]],
  true,
  function (pattern)
    return do_search (false, false, pattern)
  end
)

Defun ("search_forward_regexp",
       {"string"},
[[
Search forward from point for regular expression REGEXP.
]],
  true,
  function (pattern)
    return do_search (true, true, pattern)
  end
)

Defun ("search_backward_regexp",
       {"string"},
[[
Search backward from point for match for regular expression REGEXP.
]],
  true,
  function (pattern)
    return do_search (false, true, pattern)
  end
)

Defun ("isearch_forward",
       {},
[[
Do incremental search_forward.
With a prefix argument, do an incremental regular expression search instead.
As you type characters, they add to the search string and are found.
Type return to exit, leaving point at location found.
Type @kbd{C-s} to search again forward, @kbd{C-r} to search again backward.
@kbd{C-g} when search is successful aborts and moves point to starting point.
]],
  true,
  function ()
    return isearch (true, lastflag.set_uniarg)
  end
)

Defun ("isearch_backward",
       {},
[[
Do incremental search_backward.
With a prefix argument, do a regular expression search instead.
As you type characters, they add to the search string and are found.
Type return to exit, leaving point at location found.
Type @kbd{C-r} to search again backward, @kbd{C-s} to search again forward.
@kbd{C-g} when search is successful aborts and moves point to starting point.
]],
  true,
  function ()
    return isearch (false, lastflag.set_uniarg)
  end
)

Defun ("isearch_forward_regexp",
       {},
[[
Do incremental search_forward for regular expression.
With a prefix argument, do a regular string search instead.
Like ordinary incremental search except that your input
is treated as a regexp.  See @kbd{M-x isearch_forward} for more info.
]],
  true,
  function ()
    return isearch (true, not lastflag.set_uniarg)
  end
)

Defun ("isearch_backward_regexp",
       {},
[[
Do incremental search_backward for regular expression.
With a prefix argument, do a regular string search instead.
Like ordinary incremental search except that your input
is treated as a regexp.  See @kbd{M-x isearch_backward} for more info.
]],
  true,
  function ()
    return isearch (false, not lastflag.set_uniarg)
  end
)

-- Check the case of a string.
-- Returns "uppercase" if it is all upper case, "capitalized" if just
-- the first letter is, and nil otherwise.
local function check_case (s)
  if s:match ("^%u+$") then
    return "uppercase"
  elseif s:match ("^%u%U*") then
    return "capitalized"
  end
end

Defun ("query_replace",
       {},
[[
Replace occurrences of a string with other text.
As each match is found, the user must type a character saying
what to do with it.
]],
  true,
  function ()
    local find = minibuf_read ("Query replace string: ", "")
    if not find then
      return keyboard_quit ()
    end
    if find == "" then
      return false
    end
    local find_no_upper = no_upper (find, false)

    local repl = minibuf_read (string.format ("Query replace `%s' with: ", find), "")
    if not repl then
      keyboard_quit ()
    end

    local noask = false
    local count = 0
    local ok = true
    while search (get_buffer_pt (cur_bp), find, true, false) do
      local c = keycode ' '

      if not noask then
        if thisflag.need_resync then
          window_resync (cur_wp)
        end
        minibuf_write (string.format ("Query replacing `%s' with `%s' (y, n, !, ., q)? ", find, repl))
        c = getkey (GETKEY_DEFAULT)
        minibuf_clear ()

        if c == keycode "q" then -- Quit immediately.
          break
        elseif c == keycode "\\C-g" then
          ok = keyboard_quit ()
          break
        elseif c == keycode "!" then -- Replace all without asking.
          noask = true
        end
      end

      if keyset {" ", "y", "Y", ".", "!"}:member (c) then
        -- Perform replacement.
        count = count + 1
        local case_repl = repl
        local r = region_new (get_buffer_pt (cur_bp) - #find, get_buffer_pt (cur_bp))
        if find_no_upper and get_variable_bool ("case-replace") then
          local case_type = check_case (tostring (get_buffer_region (cur_bp, r))) -- FIXME
          if case_type then
            case_repl = recase (repl, case_type)
          end
        end
        local m = point_marker ()
        goto_offset (r.start)
        replace_estr (#find, EStr (case_repl))
        goto_offset (m.o)
        unchain_marker (m)

        if c == keycode "." then -- Replace and quit.
          break
        end
      elseif not keyset {"n", "N", "\\RET", "\\DELETE"}:member (c) then
        ungetkey (c)
        ok = false
        break
      end
    end

    if thisflag.need_resync then
      window_resync (cur_wp)
    end

    if ok then
      minibuf_write (string.format ("Replaced %d occurrence%s", count, count ~= 1 and "s" or ""))
    end

    return ok
  end
)

Defun ("undo",
       {},
[[
Undo some previous changes.
Repeat this command to undo more changes.
]],
  true,
  function ()
    if cur_bp.noundo then
      minibuf_error ("Undo disabled in this buffer")
      return false
    end

    if warn_if_readonly_buffer () then
      return false
    end

    if not cur_bp.next_undop then
      minibuf_error ("No further undo information")
      cur_bp.next_undop = cur_bp.last_undop
      return false
    end

    cur_bp.next_undop = revert_action (cur_bp.next_undop)
    minibuf_write ("Undo!")

    command.attach_label (":undo")
  end
)

Defun ("revert_buffer",
       {},
[[
Undo until buffer is unmodified.
]],
  true,
  function ()
    -- FIXME: save pointer to current undo action and abort if we get
    -- back to it.
    while cur_bp.modified do
      eval.execute_function ("undo")
    end
  end
)

Defun ("set_variable",
       {"string", "string"},
[[
Set a variable value to the user-specified value.
]],
  true,
  function (var, val)
    local ok = true

    if not var then
      var = minibuf_read_variable_name ("Set variable: ")
    end
    if not var then
      return false
    end
    if not val then
      val = minibuf_read (string.format ("Set %s to value: ", var), "")
    end
    if not val then
      ok = keyboard_quit ()
    end

    if ok then
      set_variable (var, val)
    end

    return ok
  end
)

Defun ("delete_window",
       {},
[[
Remove the current window from the screen.
]],
  true,
  function ()
    if #windows == 1 then
      minibuf_error ("Attempt to delete sole ordinary window")
      return false
    end

    delete_window (cur_wp)
  end
)

Defun ("enlarge_window",
       {},
[[
Make current window one line bigger.
]],
  true,
  function ()
    if #windows == 1 then
      return false
    end

    local wp = cur_wp.next
    if not wp or wp.fheight < 3 then
      for _, wp in ipairs (windows) do
        if wp.next == cur_wp then
          if wp.fheight < 3 then
            return false
          end
          break
        end
      end

      if cur_wp == windows[#windows] and cur_wp.next.fheight < 3 then
        return false
      end

      wp.fheight = wp.fheight - 1
      wp.eheight = wp.eheight - 1
      if wp.topdelta >= wp.eheight then
        recenter (wp)
      end
      cur_wp.fheight = cur_wp.fheight + 1
      cur_wp.eheight = cur_wp.eheight + 1
    end
  end
)

Defun ("shrink_window",
       {},
[[
Make current window one line smaller.
]],
  true,
  function ()
    if #windows == 1 or cur_wp.fheight < 3 then
      return false
    end

    local next_wp = window_next (cur_wp)
    next_wp.fheight = next_wp.fheight + 1
    next_wp.eheight = next_wp.eheight + 1
    cur_wp.fheight = cur_wp.fheight - 1
    cur_wp.eheight = cur_wp.eheight - 1
    if cur_wp.topdelta >= cur_wp.eheight then
      recenter (next_wp)
    end
  end
)

Defun ("delete_other_windows",
       {},
[[
Make the selected window fill the screen.
]],
  true,
  function ()
    for _, wp in ipairs (table.clone (windows)) do
      if wp ~= cur_wp then
        delete_window (wp)
      end
    end
  end
)

Defun ("other_window",
       {},
[[
Select the first different window on the screen.
All windows are arranged in a cyclic order.
This command selects the window one step away in that order.
]],
  true,
  function ()
    set_current_window (window_next (cur_wp))
  end
)

Defun ("split_window",
       {},
[[
Split current window into two windows, one above the other.
Both windows display the same buffer now current.
]],
  true,
  split_window
)
