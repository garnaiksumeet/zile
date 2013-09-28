-- Zile variables
--
-- Copyright (c) 1997-2010, 2012-2013 Free Software Foundation, Inc.
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


-- Some of the code in lib.zile behaves differently depending on the
-- values of variables Defvar'd below, but the variable names exposed
-- to the user may not be appropriate in some editor implementations,
-- so we maintain 'varname_map' as a way of translating from the
-- lookups with editor sepecific names into the canonical keys used
-- to actually store the variable metadata.
varname_map = {}

main_vars = {}

local function Defvar (name, value, doc, local_when_set)
  -- Zmacs variables use '-' in place of '_' for user visible names.
  local key = name:gsub ("-", "_")

  varname_map [name] = key
  main_vars[key] = {
    val = value,
    doc = texi (doc:chomp ()),
    islocal = local_when_set,
  }
end


Defvar ("inhibit-splash-screen", "nil",
[[
Non-nil inhibits the startup screen.
It also inhibits display of the initial message in the `*scratch*' buffer.
]],
  false)


Defvar ("standard-indent", "4",
[[
Default number of columns for margin-changing functions to indent.
]],
  false)


Defvar ("tab-width", "8",
[[
Distance between tab stops (for display of tab characters), in columns.
]],
  true)


Defvar ("tab-always-indent", "t",
[[
Controls the operation of the @kbd{TAB} key.
If @samp{t}, hitting @kbd{TAB} always just indents the current line.
If @samp{nil}, hitting @kbd{TAB} indents the current line if point is at the
left margin or in the line's indentation, otherwise it inserts a
"real" TAB character.
]],
  false)


Defvar ("indent-tabs-mode", "t",
[[
If non-nil, insert-tab inserts "real" tabs; otherwise, it always inserts
spaces.
]],
  true)


Defvar ("fill-column", "70",
[[
Column beyond which automatic line-wrapping should happen.
Automatically becomes buffer-local when set in any fashion.
]],
  true)


Defvar ("auto-fill-mode", "nil",
[[
If non-nil, Auto Fill Mode is automatically enabled.
]],
  false)


Defvar ("kill-whole-line", "nil",
[[
If non-nil, `kill-line' with no arg at beg of line kills the whole line.
]],
  false)


Defvar ("case-fold-search", "t",
[[
Non-nil means searches ignore case.
]],
  true)


Defvar ("case-replace", "t",
[[
Non-nil means `query-replace' should preserve case in replacements.
]],
  false)


Defvar ("ring-bell", "t",
[[
Non-nil means ring the terminal bell on any error.
]],
  false)


Defvar ("highlight-nonselected-windows", "nil",
[[
If non-nil, highlight region even in nonselected windows.
]],
  false)


Defvar ("make-backup-files", "t",
[[
Non-nil means make a backup of a file the first time it is saved.
This is done by appending `@samp{~}' to the file name.
]],
  false)


Defvar ("backup-directory", "nil",
[[
The directory for backup files, which must exist.
If this variable is @samp{nil}, the backup is made in the original file's
directory.\nThis value is used only when `make-backup-files' is @samp{t}.
]],
  false)
