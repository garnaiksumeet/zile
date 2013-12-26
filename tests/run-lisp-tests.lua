-- run-lisp-tests
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

posix = require "posix"
require "std"

-- N.B. Tests that use execute-kbd-macro must note that keyboard input
-- is only evaluated once the script has finished running.

-- The following are defined in the environment for a build
local srcdir = os.getenv ("srcdir") or "."
local abs_srcdir = os.getenv ("abs_srcdir") or "."
local builddir = os.getenv ("builddir") or "."
local EMACSPROG = os.getenv ("EMACSPROG") or ""

local zile_pass = 0
local zile_fail = 0
local emacs_pass = 0
local emacs_fail = 0

local zile_cmd = io.catfile (builddir, "lib", "zmacs", "zmacs")
local srcdir_pat = string.escapePattern (srcdir)

function run_test (test, name, editor_name, edit_file, cmd, args)
  posix.spawn ({"cp", io.catfile (srcdir, "tests", "test.input"), edit_file})
  posix.spawn ({"chmod", "+w", edit_file})
  local status = posix.spawn ({cmd, unpack (args)})
  if status == 0 then
    if posix.spawn ({"diff", test .. ".output", edit_file}) == 0 then
      posix.spawn ({"rm", "-f", edit_file, edit_file .. "~"})
      return true
    else
      print (editor_name .. " " .. name .. " failed to produce correct output")
    end
  else
    print (editor_name .. " " .. name .. " failed to run with error code " .. tostring (status))
  end
end

for _, name in ipairs (arg) do
  local test = name:gsub ("%.el$", "")
  if io.open (test .. ".output") ~= nil then
    name = test:gsub (io.catfile (srcdir, "tests/"), "")
    local edit_file = test:gsub ("^" .. srcdir_pat, builddir) .. ".input"
    local args = {"--no-init-file", edit_file, "--load", test:gsub ("^" .. srcdir_pat, abs_srcdir) .. ".el"}

    posix.spawn ({"mkdir", "-p", posix.dirname (edit_file)})

    if EMACSPROG ~= "" then
      if run_test (test, name, "Emacs", edit_file, EMACSPROG, list.concat (args, {"--quick", "--batch"})) then
        emacs_pass = emacs_pass + 1
      else
        emacs_fail = emacs_fail + 1
        os.rename (edit_file, edit_file .. "-emacs")
        os.rename (edit_file .. "~", edit_file .. "-emacs~")
      end
    end

    if run_test (test, name, "Zile", edit_file, zile_cmd, args) then
      zile_pass = zile_pass + 1
    else
      zile_fail = zile_fail + 1
    end
  end
end

print (string.format ("Zile: %d pass(es) and %d failure(s)", zile_pass, zile_fail))
print (string.format ("Emacs: %d pass(es) and %d failure(s)", emacs_pass, emacs_fail))

os.exit (zile_fail + emacs_fail)
