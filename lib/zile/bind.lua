-- Key bindings and extended commands
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

-- Key binding.

-- Initialise prefix arg
prefix_arg = false -- Not nil, so it is picked up in environment table
current_prefix_arg = false

function execute_with_uniarg (undo, uniarg, forward, backward)
  uniarg = uniarg or 1

  if backward and uniarg < 0 then
    forward = backward
    uniarg = -uniarg
  end
  if undo then
    undo_start_sequence ()
  end
  local ret = true
  for _ = 1, uniarg do
    ret = forward ()
    if not ret then
      break
    end
  end
  if undo then
    undo_end_sequence ()
  end

  return ret
end

function move_with_uniarg (uniarg, move)
  local ret = true
  for uni = 1, math.abs (uniarg) do
    ret = move (uniarg < 0 and - 1 or 1)
    if not ret then
      break
    end
  end
  return ret
end

local prev_label = nil
local this_label = nil
local interactive = 0

command = {
  is_interactive = function ()
    return interactive > 0
  end,

  interactive_enter = function ()
    interactive = interactive + 1
  end,

  interactive_exit = function ()
    interactive = math.max (0, interactive -1)
  end,

  -- Commands that behave differently for particular immediately preceding
  -- commands (e.g. consecutive kill commands append to the kill buffer)
  -- attach and verify labels with the following two methods.
  attach_label = function (label)
    this_label = label
  end,

  was_labelled = function (label)
    return prev_label == label
  end,

  next_label = function ()
    prev_label = this_label
  end,
}

function self_insert_command ()
  local key = term_keytobyte (lastkey ())
  deactivate_mark ()
  if not key then
    ding ()
    return false
  end

  if string.char (key):match ("%s") and cur_bp.autofill and
    get_goalc () > eval.get_variable_number ("fill_column")
  then
    fill_break_line ()
  end

  insert_char (string.char (key))
  return true
end

function do_binding_completion (as)
  local bs = ""

  if lastflag.set_uniarg then
    local arg = math.abs (prefix_arg or 1)
    repeat
      bs = string.char (arg % 10 + string.byte ('0')) .. " " .. bs
      arg = math.floor (arg / 10)
    until arg == 0
  end

  if prefix_arg and prefix_arg < 0 then
    bs = "- " .. bs
  end

  minibuf_write (((lastflag.set_uniarg or lastflag.uniarg_empty) and "C-u " or "") ..
                 bs .. as .. "-")
  local key = getkey (GETKEY_DEFAULT)
  minibuf_clear ()

  return key
end

function walk_bindings (tree, process, st)
  local function walk_bindings_tree (tree, keys, process, st)
    for key, node in pairs (tree) do
      table.insert (keys, tostring (key))
      if iscallable (node) then
        process (table.concat (keys, " "), node, st)
      else
        walk_bindings_tree (node, keys, process, st)
      end
      table.remove (keys)
    end
  end

  walk_bindings_tree (tree, {}, process, st)
end

-- Get a key sequence from the keyboard; the sequence returned
-- has at most the last stroke unbound.
function get_key_sequence ()
  local keys = keystrtovec ""

  local key
  repeat
    key = getkey (GETKEY_DEFAULT)
  until key ~= nil
  table.insert (keys, key)

  local func
  while true do
    func = root_bindings[keys]
    if not func or iscallable (func) then
      break
    end
    local s = tostring (keys)
    table.insert (keys, do_binding_completion (s))
  end

  return keys
end

function get_function_by_keys (keys, fetch)
  local func = root_bindings[keys]
  return iscallable (func) and func or nil
end

-- gather_bindings_state:
-- {
--   f: name of function
--   bindings: bindings
-- }

function gather_bindings (key, p, g)
  if p == g.f then
    if #g.bindings > 0 then
      g.bindings = g.bindings .. ", "
    end
    g.bindings = g.bindings .. key
  end
end

function prompt_key_sequence (prompt, keystr)
  local keys
  if keystr then
    keys = keystrtovec (keystr)
    if not keys then
      return nil, string.format ("Key sequence %s is invalid", keystr)
    end
  else
    minibuf_write (prompt .. ": ")
    keys = get_key_sequence ()
  end
  return keys
end
