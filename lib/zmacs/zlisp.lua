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
-- along with this program.  If not, see <htt://www.gnu.org/licenses/>.

--[[--
 Zile Lisp interpreter.

 A very basic lisp environment, with a source parser and an _S-Expression_
 evaluator.  The execution environment is empty, so nothing useful can
 be achieved until some commands to build the S-Expressions have been
 defined.

 There is no concept of 'nil', '#T' or the like.  Depending on the
 particular dialect of Lisp you want to write, you'll need to define those
 yourself too.

 The parser returns error messages starting with source code line numbers
 for mismatched quote marks and parentheses, at least for non-pathological
 input.

 The scanner is not terribly smart, and doesn't understand escaped
 characters, so don't use nested escaped quotes!

 @module zmacs.zlisp
]]

local Cons = require "zile.Cons"
local Set  = require "zile.Set"
local io   = require "std.io_ext"



--[[ ========================= ]]--
--[[ ZLisp scanner and parser. ]]--
--[[ ========================= ]]--


local isskipped   = Set { ";", " ", "\t", "\n", "\r" }
local isoperator  = Set { "(", ")", "'" }
local isdelimiter = Set { '"' } + isskipped + isoperator


--- Return the 1-based line number at which index `i' occurs in `s'.
-- @string s zlisp source
-- @int    i 1-based index into `s`
-- @treturn int number of `\n` characters in `s` upto and including
--   the line containing the character at index `i`
local function iton (s, i)
  local n = 1
  for _ in string.gmatch (s:sub (1, i), "\n") do n = n + 1 end
  return n
end


--- Increment index into s and return that character.
-- @string s zlisp source
-- @int    i index of last character scanned so far
-- @treturn char|nil next unscanned character or nil when end is reached
-- @treturn int      i + 1
local function nextch (s, i)
  return i < #s and s[i + 1] or nil, i + 1
end


--- Lexical scanner for zlisp code.
-- Comments and whitespace are silently skipped over.
-- @string s zlisp source
-- @int    i index of last character scanned so far
-- @treturn string text of just scanned `token`, or "" for an operator
-- @treturn string `kind` of token: one of `eof`, `string`, `word` or
--   a character from the `isoperator` set above
-- @treturn int    the index of the next unscanned character in `s`
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


--- Parse a string of zlisp code into an abstract syntax tree.
-- @string s zlisp source
-- @treturn zile.Cons the AST as a list of _S-Expressions_; in case of
--   error it returns `nil` plus an error message that contains the line
--   number of `s` where parsing failed.
local function parse (s)
  local i = 0

  -- New nodes are pushed onto the front of the list for speed...
  local function push (ast, value, kind, quoted)
    return Cons ({value = value, kind = kind, quoted = quoted}, ast)
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


--- ZLisp symbols.
-- A mapping of symbol-names to symbol-values.
-- @table obarray
local obarray = {}


--- Define a new symbol.
-- @string name the symbol name
-- @param value the value to store in symbol `name`
local function define (name, value)
  obarray[name] = value
end


--- Fetch the value of a defined symbol name.
-- @string name the symbol name
-- @return the associated symbol value if any, else `nil`
local function fetch (name)
  return obarray[name]
end


--- Symbol table iterator, for use with `for` loops.
--     for name, value in zlisp.symbols() do
-- @treturn function iterator
-- @treturn table symbol table
local function symbols ()
  return next, obarray, nil
end



--[[ ================ ]]--
--[[ ZLisp Evaluator. ]]--
--[[ ================ ]]--


--- Call a named zlisp command with arguments.
-- @string name a function @{define}d in @{obarray}
-- @tparam zile.Cons arglist arguments for `name`
-- @return the result of calling `name` with `arglist`, or else `nil`
local function call_command (name, arglist)
  local value = obarray[name]
  return value and type (value) == "function" and value (arglist) or nil
end


--- Evaluate a single command expression.
-- @tparam zile.Cons list a cons list, where the first element is a
--   command name.
-- @return the result of evaluating `list`, or else `nil`
local function evaluate_command (list)
  return list and list.car and call_command (list.car.value, list.cdr) or nil
end


--- Evaluate a string of zlisp code.
-- @string s zlisp source
-- @return `true` for success, or else `nil` plus an error string
local function evaluate_string (s)
  -- convert error calls in parse to `nil, "errmsg"' return value.
  local ok, list = pcall (parse, s)
  if not ok then return nil, list end

  while list do
    evaluate_command (list.car.value)
    list = list.cdr
  end
  return true
end


--- Evaluate a file of zlisp.
-- @param file path to a file of zlisp code
-- @return `true` for success, or else `nil` plus an error string
local function evaluate_file (file)
  local s, errmsg = io.slurp (file)

  if s then
    s, errmsg = evaluate_string (s)
  end

  return s, errmsg
end


------
--- Return a new Cons cell with supplied car and cdr.
-- @function Cons
-- @param car first element
-- @param cdr last element
-- @treturn Cons a new cell containing those elements


--- @export
return {
  call_command    = call_command,
  Cons            = Cons,
  define          = define,
  evaluate_file   = evaluate_file,
  evaluate_string = evaluate_string,
  fetch           = fetch,
  parse           = parse,
  symbols         = symbols,
}
