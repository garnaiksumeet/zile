-- Zile Lisp interpreter
--
-- Copyright (c) 2009-2013 Free Software Foundation, Inc.
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
-- along with this program; see the file COPYING.  If not, write to the
-- Free Software Foundation, Fifth Floor, 51 Franklin Street, Boston,
-- MA 02111-1301, USA.


local Set = require "zile.Set"
local io  = require "std.io_ext"

local M = {}



--[[ ----------- ]]--
--[[ Cons Cells. ]]--
--[[ ----------- ]]--


local Cons = {}
local metatable = { __index = Cons }


-- Construct and return a new cons cell:
--   new = M.cons (car, cdr)
function M.cons (car, cdr)
  return setmetatable ({car = car, cdr = cdr}, metatable)
end


-- Return the nth element of a list of cons cells.
function Cons:nth (n)
  if type (n) ~= "number" or n < 1 or self == nil then
    return nil
  elseif n == 1 then
    return self.car
  end

  -- Weird calling convention to enable tail call elimination.
  return Cons.nth (self.cdr, n - 1)
end


-- Equivalent to table.concat for lists of cons cells.  Concatenates
-- value field of each car if available, otherwise all of car itself.
function Cons:concat (delim)
  delim = delim or ""
  local s = tostring (self.car.value or self.car)
  if self.cdr == nil then return s end
  return s .. delim .. Cons.concat (self.cdr, delim)
end


-- Return a non-destructive reversed cons list.
function Cons:reverse ()
  local rev = nil
  while self ~= nil do
    rev = M.cons (self.car, rev)
    self = self.cdr
  end
  return rev
end



--[[ ========================= ]]--
--[[ ZLisp scanner and parser. ]]--
--[[ ========================= ]]--


local isskipped   = Set { ";", " ", "\t", "\n", "\r" }
local isoperator  = Set { "(", ")", "'" }
local isdelimiter = Set { '"' } + isskipped + isoperator


-- Return the 1-based line number at which offset `o' occurs in `s'.
local function iton (s, i)
  local n = 1
  for _ in string.gmatch (s:sub (1, i), "\n") do n = n + 1 end
  return n
end


-- Increment index into s and return that character.
local function nextch (s, i)
  return i < #s and s[i + 1] or nil, i + 1
end


-- Lexical scanner: Return three values: `token', `kind', `i', where
-- `token' is the content of the just scanned token, `kind' is the
-- type of token returned, and `i' is the index of the next unscanned
-- character in `s'.
local function lex (s, i)
  -- Skip initial whitespace and comments.
  local c
  repeat
    c, i = nextch (s, i)

    -- Comments start with `;'.
    if c == ';' then
      repeat
        c, i = nextch (s, i)
      until c == '\n' or c == '\r' or c == nil
    end

    -- Continue skipping additional lines of comments and whitespace.
  until c == nil or not isskipped[c]

  -- Return end-of-file immediately.
  if c == nil then return nil, "eof", i end

  -- Return operator tokens.
  -- These are returned in the `kind' field so we can immediately tell
  -- the difference between a ')' delimiter and a ")" string token.
  if isoperator[c] then
    return "", c, i
  end

  -- Strings start and end with `"'.
  -- Note we read another character immediately to skip the opening
  -- quote, and don't append the closing quote to the returned token.
  local token = ''
  if c == '"' then
    repeat
      c, i = nextch (s, i)
      if c == nil then
        error (iton (s, i - 1) .. ': incomplete string "' .. token, 0)
      elseif c ~= '"' then
        token = token .. c
      end
    until c == '"'

    return token, "string", i
  end

  -- Anything else is a `word' - up to the next whitespace or delimiter.
  repeat
    token = token .. c
    c, i = nextch (s, i)
    if isdelimiter[c] or c == nil then
      return token, "word", i - 1
    end
  until false
end


-- Call `lex' repeatedly to build and return an abstract syntax-tree
-- representation of the ZLisp code in `s'.
function M.parse (s)
  local i = 0

  -- New nodes are pushed onto the front of the list for speed...
  local function push (ast, value, kind, quoted)
    return M.cons ({value = value, kind = kind, quoted = quoted}, ast)
  end

  local function read (nested, openparen)
    local ast, token, kind, quoted
    repeat
      token, kind, i = lex (s, i)
      if kind == "'" then
        quoted = kind
      else
        if kind == "(" then
	  local subtree, errmsg = read (true, i)
	  if errmsg ~= nil then return ok, errmsg end
          ast = push (ast, subtree, nil, quoted)

        elseif kind == "word" or kind == "string" then
          ast = push (ast, token, kind, quoted)

	elseif kind == ")" then
          if not nested then
            error (iton (s, i) .. ": unmatched close parenthesis", 0)
	  end
	  openparen = nil
	  break
        end
        quoted = nil
      end
    until kind == "eof"

    if openparen ~= nil then
      error (iton (s, openparen) .. ": unmatched open parenthesis", 0)
    end

    -- ...and then the whole list is reversed once completed.
    return ast and ast:reverse () or nil
  end

  -- `false' argument allows detection of unmatched outer `)' tokens.
  return read (false)
end



--[[ ======================== ]]--
--[[ Symbol Table Management. ]]--
--[[ ======================== ]]--


-- ZLisp symbols.
M.symbol = {}


-- Define a new symbol.
function M.define (name, value)
  M.symbol[name] = value
end


-- Iterator returning (name, entry) for each symbol.
function M.symbols ()
  return next, M.symbol, nil
end



--[[ ================ ]]--
--[[ ZLisp Evaluator. ]]--
--[[ ================ ]]--


-- Execute a function non-interactively.
function M.call_command (name, arglist)
  local value = M.symbol[name]
  return value and type (value) == "function" and value (arglist) or nil
end


-- Evaluate a list of command expressions.
local function evalexpr (list)
  return list and list.car and M.call_command (list.car.value, list.cdr) or nil
end


-- Evaluate a string of ZLisp.
function M.evalstring (s)
  -- convert error calls in M.parse to `nil, "errmsg"' return value.
  local ok, list = pcall (M.parse, s)
  if not ok then return nil, list end

  while list do
    evalexpr (list.car.value)
    list = list.cdr
  end
  return true
end


-- Evaluate a file of ZLisp.
function M.evalfile (file)
  local s, errmsg = io.slurp (file)

  if s then
    s, errmsg = M.evalstring (s)
  end

  return s, errmsg
end


return M
