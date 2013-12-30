-- Variable facility commands.
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
local Defun, Defvar = eval.Defun, eval.Defvar
local set_variable_buffer_local = eval.set_variable_buffer_local


Defvar ("inhibit_splash_screen", "nil",
[[
Non-nil inhibits the startup screen.
It also inhibits display of the initial message in the `*scratch*'
buffer.
]])


Defvar ("standard_indent", "4",
[[
Default number of columns for margin-changing functions to indent.
]])


Defvar ("tab_width", "8",
[[
Distance between tab stops (for display of tab characters), in columns.
]])
set_variable_buffer_local ("tab_width", true)


Defvar ("tab_always_indent", "t",
[[
Controls the operation of the @kbd{TAB} key.
If @samp{t}, hitting @kbd{TAB} always just indents the current line.
If @samp{nil}, hitting @kbd{TAB} indents the current line if point is at the
left margin or in the line's indentation, otherwise it inserts a
"real" TAB character.
]])


Defvar ("indent_tabs_mode", "t",
[[
If non-nil, insert-tab inserts "real" @kbd{TAB}s; otherwise, it always inserts
spaces.
]])
set_variable_buffer_local ("indent_tabs_mode", true)


Defvar ("fill_column", "70",
[[
Column beyond which automatic line-wrapping should happen.
Automatically becomes buffer-local when set in any fashion.
]])
set_variable_buffer_local ("fill_column", true)


Defvar ("auto_fill_mode", "nil",
[[
If non-nil, Auto Fill Mode is automatically enabled.
]])


Defvar ("kill_whole_line", "nil",
[[
If non-nil, `kill_line' with no arg at beg of line kills the whole line.
]])


Defvar ("case_fold_search", "t",
[[
Non-nil means searches ignore case.
]])
set_variable_buffer_local ("case_fold_search", true)


Defvar ("case_replace", "t",
[[
Non-nil means `query_replace' should preserve case in replacements.
]])


Defvar ("ring_bell", "t",
[[
Non-nil means ring the terminal bell on any error.
]])


Defvar ("highlight_nonselected_windows", "nil",
[[
If non-nil, highlight region even in nonselected windows.
]])


Defvar ("make_backup_files", "t",
[[
Non-nil means make a backup of a file the first time it is saved.
This is done by appending `@samp{~}' to the file name.
]])


Defvar ("backup_directory", "nil",
[[
The directory for backup files, which must exist.
If this variable is @samp{nil}, the backup is made in the original file's
directory.\nThis value is used only when `make_backup_files' is @samp{t}.
]])


Defun ("set_variable",
  {"string", "string"},
[[
Set a variable value to the user-specified value.
]],
  true,
  function (var, val)
    local ok = true

    if not var then
      var = minibuf_read_variable_name ('Set variable: ')
    end
    if not var then
      return false
    end
    if not val then
      val = minibuf_read (string.format ('Set %s to value: ', var), '')
    end
    if not val then
      ok = keyboard_quit ()
    end

    if ok then
      eval.set_variable (var, val)
    end

    return ok
  end
)
