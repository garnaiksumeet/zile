-- Zi variables
--
-- Copyright (c) 1997-2010, 2012 Free Software Foundation, Inc.
--
-- This file is part of GNU Zi.
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

local mode_map = {
  ["%.[ch]$"] = "c",
  ["%.lua$"]  = "lua",
  ["%.sh$"]   = "sh",
}

X ("inhibit_splash_screen", false, false, "When set to @samp{true}, inhibits the startup screen.\nIt also inhibits display of the initial message in the `*scratch*' buffer.")
X ("standard_indent", 4, false, "Default number of columns for margin-changing functions to indent.")
X ("tab_width", 8, true, "Distance between tab stops (for display of tab characters), in columns.")
X ("tab_always_indent", true, false, "Controls the operation of the @kbd{TAB} key.\nIf @samp{true}, hitting @kbd{TAB} always just indents the current line.\nIf @samp{false}, hitting @kbd{TAB} indents the current line if point is at the\nleft margin or in the line's indentation, otherwise it inserts a\n\"real\" TAB character.")
X ("indent_tabs_mode", true, true, "If @samp{true}, insert_tab inserts \"real\" tabs. If @samp{false}, it always inserts\nspaces.")
X ("fill_column", 70, true, "Column beyond which automatic line-wrapping should happen.\nAutomatically becomes buffer-local when set in any fashion.")
X ("auto_fill_mode", false, false, "If @samp{true}, Auto Fill Mode is automatically enabled.")
X ("kill_whole_line", false, false, "If @samp{true}, `kill_line' with no arg at beg of line kills the whole line.")
X ("case_fold_search", true, true, "When @samp{true}, searches ignore case.")
X ("case_replace", true, false, "When @samp{true}, `query_replace' preserves case in replacements.")
X ("ring_bell", true, false, "When @samp{true}, ring the terminal bell on any error.")
X ("highlight_nonselected_windows", false, false, "If @samp{true}, highlight region even in nonselected windows.")
X ("make_backup_files", true, false, "When @samp{true}, make a backup of a file the first time it is saved.\nThis is done by appending `@samp{~}' to the file name.")
X ("backup_directory", false, false, "The directory for backup files, which must exist.\nIf this variable is @samp{false}, the backup is made in the original file's\ndirectory.\nThis value is used only when `make_backup_files' is @samp{true}.")
X ("mode_map", mode_map, false, "Mapping filename matches to language modes.")
