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


-- This file implements a two stage syntax highlighter:
--
-- 1. Search for matches against patterns in the current grammar from
--    left to right, adding appropriate color pushes and pops at the
--    match begin and end locations;
-- 2. Step through each character cell pushing any new colors for that
--    cell onto a stack according to the instructions from step 1, then
--    setting the cell to the color on the top of that stack (if any)
--    and then finally popping any colors as instructed by step 1.


-- Syntax parser state.
local state = {}


-- Metamethods for syntax parser state.
local metatable = {

  -- Queue an operation for pushing or popping value v to the
  -- stack at offset o.
  push_op = function (self, op, o, v)
    if not v then return nil end
    local st = self.syntax.ops
    st[o] = st[o] or stack.new ()
    st[o]:push { [op] = v }
  end,

  -- Return the current capture offsets.
  top_caps = function (self)
    local top = self.syntax.caps:top ()
    if top then return top.caps, top.begin end
  end,

  -- Accessor methods.
  get_attrs     = function (self) return self.syntax.attrs end,
  get_caps      = function (self) return self.syntax.caps end,
  get_colors    = function (self) return self.syntax.colors end,
  get_highlight = function (self) return self.syntax.highlight end,
  get_ops       = function (self) return self.syntax.ops end,
  get_pats      = function (self) return self.syntax.pats end,
  get_repo      = function (self) return self.repo end,
  get_s         = function (self) return self.s end,

}


-- Return a new parser state for the buffer line n.
function state.new (bp, o)
  local n = offset_to_line (bp, o)

  bp.syntax[n] = {
    -- calculate the attributes for each cell of this line using a stack-
    -- machine with color push and pop operations
    attrs = {},
    ops   = {},

    -- parser state for the current line
    caps      = stack.new (),
    colors    = stack.new (),
    highlight = stack.new (),
    pats      = stack.new {bp.grammar.patterns},
  }

  local bol    = buffer_start_of_line (bp, o)
  local eol    = bol + buffer_line_len (bp, o)
  local region = get_buffer_region (bp, {start = bol, finish = eol})
  local lexer  = {
    repo    = bp.grammar.repository,
    s       = tostring (region),
    syntax  = bp.syntax[n],
  }

  return setmetatable (lexer, {__index = metatable})
end


-- Marshal 0-indexed buffer API into and out-of 1-indexed onig API.
local function rex_exec (rex, s, i)
  local b, e, caps = rex:exec (s, i + 1)

  for k,v in pairs (caps or {}) do
    -- onig stores unmatched captures as `false'
    if v then caps[k] = v - 1 end
  end

  if caps and table.empty (caps) then caps = nil end

  return b and (b - 1), e and (e - 1), caps
end


-- Marshal 0-indexed offsets into 1-indexed string.sub API.
local function string_sub (s, b, e)
  return s:sub (b + 1, e + 1)
end


-- Expand back-references using captures from begin string.
-- Used to replace unexpanded backrefs in pattern.end expressions
-- with captures from pattern.begin execution.
local function expand (lexer, match)
  local begincaps, begin = lexer:top_caps ()

  if not match or not begincaps then return nil end

  local b, e = 0, 0
  repeat
    b, e = match:find ("\\.", 1+ e)
    if e then
      local n = match:sub (e, e):match ("%d")
      if n then
        -- begincaps was adjusted to 0-based indexing by rex_exec
        local replace = string_sub (begin, begincaps[(n*2)-1], begincaps[n*2])
        match = match:sub (1, b -1) .. replace .. match:sub (e+1)
        e = b + #replace  -- skip over replace contents
      end
    end
  until b == nil

  return compile_rex (match)
end


-- Find the leftmost matching expression.
local function leftmost_match (lexer, i, pats)
  local b, e, caps, p

  local repo = lexer:get_repo ()
  local s    = lexer:get_s ()

  for _,v in ipairs (pats) do
    local _p  = v.include and repo[v.include] or v
    local rex = expand (lexer, _p.match) or _p.rex or _p.finish

    -- match next candidate expression
    local _b, _e, _caps
    if rex then
      _b, _e, _caps = rex_exec (rex, s, i)
    elseif _p.patterns then
      _b, _e, _caps, _p = leftmost_match (lexer, i, _p.patterns)
    end

    -- save candidate if it matched earlier than last saved candidate
    if _b and (not b or _b < b) then
      b, e, caps, p = _b, _e, _caps, _p
    end
  end

  return b, e, caps, p
end


-- Parse a string from left-to-right for matches against pats,
-- queueing color push and pop instructions as we go.
local function parse (lexer)
  local b, e, caps, p

  local begincaps = lexer:get_caps ()
  local colors    = lexer:get_colors ()
  local pats      = lexer:get_pats ()

  local i = 0
  repeat
    b, e, caps, p = leftmost_match (lexer, i, pats:top ())

    if b then
      lexer:push_op ("push", b, p.colors)
      if p.captures and caps then
        for k,v in pairs (p.captures) do
          lexer:push_op ("push", caps[(k*2)-1], v)
          lexer:push_op ("pop",  caps[k*2],     v)
        end
      end
      lexer:push_op ("pop", e, p.colors)

      i = e + 1

      -- if there are subexpressions, push those on the pattern stack
      if p.patterns then
        lexer:push_op ("push", b, colors:push (p.colors))
        begincaps:push {caps = caps, begin = lexer.s}
        pats:push (p.patterns)
      end

      -- pop completed subexpressions off the pattern stack
      if p.finish then
        pats:pop ()
        begincaps:pop ()
        lexer:push_op ("pop", e, colors:pop ())
      end
    end
  until b == nil
end


-- Highlight s according to queued color operations.
local function highlight (lexer)
  parse (lexer)

  local attrs     = lexer:get_attrs ()
  local highlight = lexer:get_highlight ()
  local ops       = lexer:get_ops ()

  for i = 0, #lexer.s do
    -- set the color at this position before it can be popped.
    attrs[i] = highlight:top ()
    for _,v in ipairs (ops[i] or {}) do
      if v.push then
        highlight:push (v.push)
        -- but, override the initial color if a new one is pushed.
        attrs[i] = highlight:top ()

      elseif v.pop then
        assert (v.pop == highlight:top ())
        highlight:pop ()
      end
    end
  end

  return lexer
end


-- Return attributes for the line in bp containing o.
function syntax_attrs (bp, o)
  if not bp.grammar then return nil end

  local lexer = highlight (state.new (bp, o))

  return lexer:get_attrs ()
end
