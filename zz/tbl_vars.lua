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

main_vars = {}
function Var (name, default_value, docstring, local_when_set)
  main_vars[name] = {val = default_value, islocal = local_when_set, doc = texi (docstring)}
end

Var ("inhibit-splash-screen", nil,
[[
Non-nil inhibits the startup screen.
It also inhibits display of the initial message in the `*scratch*' buffer.
]],
  false
)

Var ("standard-indent", 4,
[[
Default number of columns for margin-changing functions to indent.
]],
  false
)

Var ("tab-width", 8,
[[
Distance between tab stops (for display of tab characters), in columns.
]],
  true
)

Var ("tab-always-indent", true,
[[
Controls the operation of the @kbd{TAB} key.
If @samp{true}, hitting @kbd{TAB} always just indents the current line.
Otherwise, hitting @kbd{TAB} indents the current line if point is at the
left margin or in the line's indentation, otherwise it inserts a
\"real\" TAB character.
]],
  false
)

Var ("indent-tabs-mode", true,
[[
If non-nil, insert-tab inserts \"real\" tabs; otherwise, it always inserts
spaces.
]],
  true
)

Var ("fill-column", 70,
[[
Column beyond which automatic line-wrapping should happen.
Automatically becomes buffer-local when set in any fashion.
]],
  true
)
  
Var ("auto-fill-mode", false,
[[
If non-nil, Auto Fill Mode is automatically enabled.
]],
  false
)
  
Var ("kill-whole-line", false,
[[
If non-nil, `kill_line' with no arg at beg of line kills the whole line.
]],
  false
)
  
Var ("case-fold-search", true,
[[
Non-nil means searches ignore case.
]],
  true
)
  
Var ("case-replace", true,
[[
Non-nil means `query_replace' should preserve case in replacements.
]],
  false
)
  
Var ("ring-bell", true,
[[
Non-nil means ring the terminal bell on any error.
]],
  false
)
  
Var ("highlight-nonselected-windows", nil,
[[
If non-nil, highlight region even in nonselected windows.
]],
  false
)
  
Var ("make-backup-files", true,
[[
Non-nil means make a backup of a file the first time it is saved.
This is done by appending `@samp{~}' to the file name.
]],
  false
)
  
Var ("backup-directory", nil,
[[
The directory for backup files, which must exist.
If this variable is @samp{nil}, the backup is made in the original file's
directory.
This value is used only when `make-backup-files' is @samp{true}.
]],
  false
)
