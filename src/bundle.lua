-- Theme Bundles
--
-- Copyright (c) 2012 Free Software Foundation, Inc.
--
-- This file is part of GNU Zi.
--
-- GNU Zi is free software; you can redistribute it and/or modify it
-- under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 3, or (at your option)
-- any later version.
--
-- GNU Zi is distributed in the hope that it will be useful, but
-- WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
-- General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with GNU Zi; see the file COPYING.  If not, write to the
-- Free Software Foundation, Fifth Floor, 51 Franklin Street, Boston,
-- MA 02111-1301, USA.


local onig = require "rex_onig"


-- Load a Zi bundle - a lua table defining editor extensions.
local function load_bundle (filename)
  local function load_bundle_string (s)
    local f, errmsg = loadstring ("return " .. s)
    if f == nil then
      return nil, errmsg
    end
    return f()
  end

  local res, errmsg

  res, errmsg = io.slurp (filename), nil
  if res then
    res, errmsg = load_bundle_string (res)
  end

  if errmsg then
    minibuf_error (string.format ("%s: %s", filename, errmsg or "loading failed"))
  end

  return res
end


-- Set up the display attributes for themename.
function set_theme (themename)
  local t = load_bundle (PATH_THEMEDIR .. "/" .. themename .. ".lua")

  -- Transform the theme-file table format into a faster attribute lookup
  -- tree in `theme'.
  if t then
    theme["normal"] = term_get_attribute (t.settings)
    if t.settings then
      theme["selection"] = term_get_attribute ({ background = t.settings.selection, fontStyle = 'bold' })
    end

    for _,v in ipairs (t) do
      theme[v.scope] = term_get_attribute (v.settings)
    end
  end
end


-- Load the grammar description for modename.
function load_grammar (modename)
  local g = load_bundle (PATH_GRAMMARDIR .. "/" .. modename .. ".syntax")

  if g and g.patterns then
    for _,v in ipairs (g.patterns) do
      if v.name then
        local key = {}
        for w in v.name:gmatch "[^.]+" do
          table.insert (key, w)
        end

        repeat
          local scope = table.concat (key, ".")
          if theme[scope] then
            v.attrs = theme[scope]
            break
          end
          table.remove (key)
        until #key == 0
      end

      local ok
      ok, v.match = pcall (onig.new, v.match, 0)
      if not ok then
        v.match = nil
      end
    end
  end

  return g
end


-- return a dictionary to map from filename extension to syntax name.
function load_file_associations ()
  local auto_mode_alist = {}
  for _, filename in pairs (posix.dir (PATH_GRAMMARDIR)) do
    local syntax = filename:match ("^(.*)%.syntax$")
    if syntax then
      local g = load_bundle (PATH_GRAMMARDIR .. "/" .. filename)
      if g then
        if type (g.fileTypes) == "string" then
          auto_mode_alist[g.fileTypes] = syntax
        elseif type (g.fileTypes) == "table" then
          for _,v in pairs (g.fileTypes) do
            auto_mode_alist[v] = syntax
          end
        end
      end
    end
  end

  return auto_mode_alist
end
