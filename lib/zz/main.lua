-- Program invocation, startup and shutdown
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


local lisp = require "zz.eval"

prog = require "zile.version"
prog.name = "zz"

splash_str = "Welcome to " .. prog.program .. [[.

Get help        C-h  (Hold down CTRL and press h)
Undo changes	C-x u        Exit ]] .. prog.Name .. [[	C-x C-c
(`C-' means use the CTRL key.  `M-' means hold the Meta (or Alt) key.
If you have no Meta key, you may type ESC followed by the character.)
Combinations like `C-x u' mean first press `C-x', then `u'.

Keys not working properly?   See the FAQ   C-h C-f

]] .. prog.version .. [[

]] .. prog.COPYRIGHT_STRING .. [[


GNU ]] .. prog.Name .. [[ comes with ABSOLUTELY NO WARRANTY; type C-h C-w for full details.
GNU ]] .. prog.Name .. [[ is Free Software--Free as in Freedom--so you can redistribute copies
of ]] .. prog.Name .. [[ and modify it; type C-h C-c to see the conditions.

Report bugs to ]] .. prog.PACKAGE_BUGREPORT .. "."


-- Runtime constants

-- Zi display attributes
display = {}

-- Keyboard handling

GETKEY_DEFAULT = -1
GETKEY_DELAYED = 2000


-- Global flags, stored in thisflag and lastflag.
-- need_resync:    a resync is required.
-- quit:           the user has asked to quit.
-- set_uniarg:     the last command modified the universal arg variable `uniarg'.
-- uniarg_empty:   current universal arg is just C-u's with no number.
-- defining_macro: we are defining a macro.


-- The current window
cur_wp = nil

-- The current buffer
cur_bp = nil

-- The global editor flags.
thisflag = {}
lastflag = {}

-- Documented options table
--
-- Documentation line: "doc", "DOCSTRING"
-- Option: "opt", long name, short name ('\0' for none), argument, argument docstring, docstring)
-- Action: "act", ARGUMENT, DOCSTRING
--
-- Options which take no argument have an optional_argument, so that,
-- as in Emacs, no argument is signalled as extraneous.

local options = {
  {"doc", "Initialization options:"},
  {"doc", ""},
  {"opt", "batch", '\0', "optional", "", "do not do interactive display; implies -q"},
  {"opt", "no-init-file", 'q', "optional", "", "do not load ~/." .. prog.name},
  {"opt", "funcall", 'f', "required", "FUNC", "call " .. prog.Name .. " Lisp function FUNC with no arguments"},
  {"opt", "load", 'l', "required", "FILE", "load " .. prog.Name .. " Lisp FILE using the load function"},
  {"opt", "help", '\0', "optional", "", "display this help message and exit"},
  {"opt", "version", '\0', "optional", "", "display version information and exit"},
  {"doc", ""},
  {"doc", "Action options:"},
  {"doc", ""},
  {"act", "FILE", "visit FILE using find-file"},
  {"act", "+LINE FILE", "visit FILE using find-file, then go to line LINE"},
}

-- Options table
local longopts = {}
for _, v in ipairs (options) do
  if v[1] == "opt" then
    table.insert (longopts, {v[2], v[4], v[3]})
  end
end

zarg = {}
qflag = false
bflag = false

function process_args ()
  -- Leading `-' means process all arguments in order, treating
  -- non-options as arguments to an option with code 1
  -- Leading `:' so as to return ':' for a missing arg, not '?'
  local line = 1
  local this_optind = 1
  for c, optarg, optind, longindex in posix.getopt (arg, "-:f:l:q", longopts) do
    if string.byte (c) == 1 then -- Non-option (assume file name)
      longindex = 6
    elseif c == '?' then -- Unknown option
      minibuf_error (string.format ("Unknown option `%s'", arg[this_optind]))
    elseif c == ':' then -- Missing argument
      io.stderr:write (string.format ("%s: Option `%s' requires an argument\n",
                                      prog.name, arg[this_optind]))
      os.exit (1)
    elseif c == 'q' then
      longindex = 1
    elseif c == 'f' then
      longindex = 2
    elseif c == 'l' then
      longindex = 3
    end

    if longindex == 0 then
      bflag = true
      qflag = true
    elseif longindex == 1 then
      qflag = true
    elseif longindex == 2 then
      table.insert (zarg, {'function', optarg})
    elseif longindex == 3 then
      table.insert (zarg, {'loadfile', canonicalize_filename (optarg)})
    elseif longindex == 4 then
      io.write ("Usage: " .. arg[0] .. " [OPTION-OR-FILENAME]...\n" ..
                "\n" ..
                "Run " .. prog.Name .. ", a lightweight text editor.\n" ..
                "\n")

      for _, v in ipairs (options) do
        if v[1] == "doc" then
          io.write (v[2] .. "\n")
        elseif v[1] == "opt" then
          local shortopt = string.format (", -%s", v[3])
          local buf = string.format ("--%s%s %s", v[2], v[3] ~= '\0' and shortopt or "", v[5])
          io.write (string.format ("%-24s%s\n", buf, v[6]))
        elseif v[1] == "act" then
          io.write (string.format ("%-24s%s\n", v[2], v[3]))
        end
      end

      io.write ("\n" ..
                "Report bugs to " .. PACKAGE_BUGREPORT .. ".\n")
      os.exit (0)
    elseif longindex == 5 then
      io.write (prog.version .. "\n" ..
                prog.COPYRIGHT_STRING .. "\n" ..
                prog.COPYRIGHT_NOTICE .. "\n")
      os.exit (0)
    elseif longindex == 6 then
      if optarg[1] == '+' then
        line = tonumber (optarg, 10)
      else
        table.insert (zarg, {'file', canonicalize_filename (optarg), line})
        line = 1
      end
    end

    this_optind = optind > 0 and optind or 1
  end
end

local function segv_sig_handler (signo)
  io.stderr:write (prog.name .. ": " .. prog.Name ..
                   " crashed.  Please send a bug report to <" ..
                   prog.PACKAGE_BUGREPORT .. ">.\r\n")
  zile_exit (true)
end

local function other_sig_handler (signo)
  local msg = prog.name .. ": terminated with signal " .. signo .. ".\n" .. debug.traceback ()
  io.stderr:write (msg:gsub ("\n", "\r\n"))
  zile_exit (false)
end

local function signal_init ()
  -- Set up signal handling
  posix.signal(posix.SIGSEGV, segv_sig_handler)
  posix.signal(posix.SIGBUS, segv_sig_handler)
  posix.signal(posix.SIGHUP, other_sig_handler)
  posix.signal(posix.SIGINT, other_sig_handler)
  posix.signal(posix.SIGTERM, other_sig_handler)
end

function main ()
  local scratch_bp

  signal_init ()

  process_args ()

  os.setlocale ("")

  if not bflag then term_init () end

  init_default_bindings ()

  -- Create the `*scratch*' buffer, so that initialisation commands
  -- that act on a buffer have something to act on.
  create_scratch_window ()
  scratch_bp = cur_bp
  insert_string (";; This buffer is for notes you don't want to save.\n;; If you want to create a file, visit that file with C-x C-f,\n;; then enter the text in that file's own buffer.\n\n")
  cur_bp.modified = false

  if not qflag then
    local s = os.getenv ("HOME")
    if s then
      lisp.loadfile (s .. "/." .. prog.name)
    end
  end

  -- Create the splash buffer & message only if no files, function or
  -- load file is specified on the command line, and there has been no
  -- error.
  if #zarg == 0 and not minibuf_contents and not get_variable_bool ("inhibit-splash-screen") then
    local bp = create_auto_buffer ("*GNU " .. prog.Name .. "*")
    switch_to_buffer (bp)
    insert_string (splash_str)
    cur_bp.readonly = true
    goto_offset (1)
  end

  -- Load files and load files and run functions given on the command line.
  local ok = true
  for i = 1, #zarg do
    local type, arg, line = zarg[i][1], zarg[i][2], zarg[i][3]

    if type == "function" then
      ok = lisp.execute_function (arg)
      if ok == nil then
        minibuf_error (string.format ("Function `%s' not defined", arg))
      end
    elseif type == "loadfile" then
      ok = lisp.loadfile (arg)
      if not ok then
        minibuf_error (string.format ("Cannot open load file: %s\n", arg))
      end
    elseif type == "file" then
      ok = find_file (arg)
      if ok then
        lisp.execute_function ("goto-line", line)
      end
    end
    if thisflag.quit then
      break
    end
  end

  if bflag then
    return
  end

  lastflag.need_resync = true

  -- Set up screen according to number of files loaded.
  if #buffers == 3 then
    -- *scratch* and two files.
    split_window ()
    switch_to_buffer (buffers[#buffers -1])
    lisp.execute_function ("other-window")
  elseif #buffers > 3 then
    lisp.execute_function ("list-buffers")
  end

  -- Reinitialise the scratch buffer to catch settings
  init_buffer (scratch_bp)

  -- Refresh minibuffer in case there was an error that couldn't be
  -- written during startup
  minibuf_refresh ()

  -- Leave cursor in correct position.
  term_redraw_cursor ()

  -- Run the main loop.
  while not thisflag.quit do
    if lastflag.need_resync then
      window_resync (cur_wp)
    end
    get_and_run_command ()
  end

  -- Tidy and close the terminal.
  term_finish ()
end
