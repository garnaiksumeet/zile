-- Lexer for shell script powered by LPeg.

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

local grammar = require "grammar"
local lpeg    = require "lpeg"

local P, R, S = lpeg.P, lpeg.R, lpeg.S

-- The following LPeg patterns are used as building blocks.
local U, L = R "AZ", R "az"        -- uppercase, lowercase
local O, D = R "07", R "09"        -- octal, decimal
local X    = D + R "AF" + R "af"   -- hexadecimal
local W    = U + L                 -- case insensitive letter
local A    = W + D + S "_"         -- identifier
local B    = -(A + S "/.-")        -- word boundary

-- Create a parser definition context.
local parser = grammar.new "Shell-script"
parser.word_boundary = B

-- Comments.
local eol  = P "\r\n" + "\n"
local line = (1 - S "\r\n\f")^0 * eol^-1
parser:define ("comment.line.octothorpe.sh", "#" * line)

-- Numbers.
parser:define ("constant.numeric.sh", lpeg.B(B) * R "09"^1 * B)

-- String literals.
parser:define ("string.quoted.single.sh", P "'" * ((1 - S "'") + (P "\\" * 1))^0 * "'")
parser:define ("string.quoted.double.sh", P '"' * ((1 - S '"') + (P "\\" * 1))^0 * '"')

-- Environment variables.
parser:define ("variable.assignment.sh", P "$" * A^1 + A^1 * #P "=")

-- Operators.
parser:define ("keyword.operator",
    "$" * S "({"
  + S "!=<>;()[]{}|`&\\"
  + "." * #P " \t"
  + (lpeg.B (B) * "-" * (L * L^-1 + P (1)) * B))

-- Keywords.
parser:define ("keyword.control.sh", parser:keywords [[
  alias bg bind break builtin caller case cd command compgen complete continue
  declare dirs disown do done echo elif else enable esac eval exec exit export
  false fc fg fi for getopts hash help history if in jobs kill let local logout
  popd printf pushd pwd read readonly return select set shift shopt source
  suspend test then time times trap true type typeset ulimit umask unalias
  unset until which while
]])

-- Common external programs.
parser:define ("support.function.external.sh", parser:keywords [[
  cat cmp cp curl cut date find grep gunzip gvim gzip kill lua make mkdir mv
  php pkill python rm rmdir rsync ruby scp sed sleep ssh sudo tar unlink wget zip
]])

-- Define an `error' token kind that consumes one character and enables
-- the parser to resume as a last resort for dealing with unknown input.
parser:define("error", 1)

-- Compile the final LPeg pattern to match any single token and return the
-- table containing the various definitions that make up the Lua parser.
return parser:compile()
