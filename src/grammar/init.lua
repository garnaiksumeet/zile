-- Infrastructure to make it easier to define parsers using LPeg.

-- Copyright (c) 2011 Peter Odding <peter@peterodding.com>
-- Copyright (c) 2012 Free Software Foundation, Inc.
--
-- This file is part of GNU Zi.
-- Based on code from http://peterodding.com/code/lua/lxsh/
--
-- Permission is hereby granted, free of charge, to any person obtaining
-- a copy of this software and associated documentation files (the
-- "Software"), to deal in the Software without restriction, including
-- without limitation the rights to use, copy, modify, merge, publish,
-- distribute, sublicense, and/or sell copies of the Software, and to
-- permit persons to whom the Software is furnished to do so, subject to
-- the following conditions:
--
-- The above copyright notice and this permission notice shall be
-- included in all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
-- EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
-- MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
-- IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
-- CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
-- TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
-- SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

M = {}

local lpeg = require "lpeg"

local B, P, R, S = lpeg.B, lpeg.P, lpeg.R, lpeg.S

-- Primitive LPeg patterns.
local D   = R "09"
local I   = R ("AZ", "az", "\127\255") + "_"
local BOS = P (function (s, i) return i == 1 end)

M.space = S "\r\n\f\t\v "

function M.literal (pattern)
  return M.space^0 * pattern
end

function M.terminal (token, pattern)
  return M.space^0 * lpeg.Cc (token) * lpeg.Cp () * pattern * lpeg.Cp ()
end


-- Transform a string with keywords into an LPeg pattern that matches a
-- keyword followed by a word boundary. This automatically takes care of
-- sorting from longest to smallest.
local function keywords (self, keywords)
  local list = {}
  for word in keywords:gmatch '%S+' do
    list[#list + 1] = word
  end
  table.sort (list, function (a, b) return #a > #b end)

  local pattern
  for _, word in ipairs (list) do
    local p = P (word)
    pattern = pattern and (pattern + p) or p
  end

  local b  = self.word_boundary or -(I + D)
  local BB = B (b, 1) + BOS  -- beginning boundary
  local EB = b + -1          -- ending boundary

  return BB * pattern * EB
end


-- Closure to define token type given name and LPeg pattern.
local function define (self, name, patt)
  local existing = self.patterns[name]
  self.patterns[#self.patterns + 1] = name
  patt = P (patt)
  self.patterns[name] = existing and (existing + patt) or patt
end


-- Closure to compile all patterns into one pattern that captures
-- (kind, text) pair.
local function compile (self)
  local Cc, Cp = lpeg.Cc, lpeg.Cp

  local function id (n)
    if n:match "meta." then
      return self.patterns[n] / function (...) return ... end
    else
      return Cc (n) * Cp () * self.patterns[n] * Cp ()
    end
  end

  local any = id (self.patterns[1])
  for i = 2, #self.patterns do
    any = any + id (self.patterns[i])
  end
  self.any = any

  return self.parser
end


-- Constructor for parsers defined using LPeg.
function M.new (language)

  -- Table of LPeg patterns to match all kinds of tokens.
  local patterns = {}

  -- Public interface of parser being constructed.
  local parser = {
    language = language,
    patterns = patterns,
  }

  -- Context in which parser is being defined (private).
  local context = {
    compile  = compile,
    define   = define,
    keywords = keywords,
    parser   = parser,
    patterns = patterns,
  }

  -- Return an iterator that produces (kind, text) on each iteration.
  function parser.gmatch (subject)
    local i = 1
    local bi, buffer = 1, {}

    return function ()
      if bi > #buffer then
        buffer = { context.any:match (subject, i) }
        bi = 1
      end
      local kind, ibeg, iend = buffer[bi], buffer[bi + 1], buffer[bi + 2]
      bi = bi + 3

      if kind and ibeg then
        i = iend
        return kind, ibeg, iend
      end
    end
  end

  -- Return the two closures used to construct the parser.
  return context
end

return M
