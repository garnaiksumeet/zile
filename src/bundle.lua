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
