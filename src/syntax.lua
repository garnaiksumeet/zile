-- Syntax Highlighting
--
-- Copyright (c) 2012 Free Software Foundation, Inc.
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

-- Syntax parser state.
local state = {}

-- Return a new parser state for the buffer line n.
function state.new (bp, o)
  local n = offset_to_line (bp, o)

  bp.syntax[n] = { attrs = {} }

  local bol    = buffer_start_of_line (bp, o)
  local eol    = bol + buffer_line_len (bp, o)
  local region = get_buffer_region (bp, {start = bol, finish = eol})
  local parser = {
    grammar = bp.grammar,
    s       = tostring (region),
    syntax  = bp.syntax[n],
  }

  return parser
end


-- Highlight s according to queued color operations.
local function highlight (parser)
  local gmatch = parser.grammar.gmatch
  local s      = parser.s
  local attrs  = parser.syntax.attrs

  for k,b,e in gmatch (s) do
    local key, attr = {}, nil
    for w in k:gmatch "[^.]+" do
      table.insert (key, w)
    end

    repeat
      local scope = table.concat (key, ".")
      if theme[scope] then
        attr = theme[scope]
        break
      end
      table.remove (key)
    until #key == 0

    if attr then
      for i = b, e - 1 do
       attrs[i] = attrs[i] or attr
      end
    end
  end

  return parser
end


-- Return attributes for the line in bp containing o.
function syntax_attrs (bp, o)
  if not bp.grammar then return nil end

  local parser = highlight (state.new (bp, o))

  return parser.syntax.attrs
end
