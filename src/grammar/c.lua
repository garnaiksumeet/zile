-- Lexer for C source code powered by LPeg.

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
local O, D    = R "07", R "09"         -- octal, decimal
local X       = D + R ("AF", "af")     -- hexadecimal
local I       = R ("AZ", "az") + "_"   -- identifier
local B       = -(I + D)               -- word boundary
local endline = S "\r\n\f"             -- end of line character
local newline = "\r\n" + endline       -- newline sequence
local escape  = "\\" * (newline        -- escape sequence
                        + S "\\\"'?abfnrtv"
                        + (#O * O^-3)
                        + ("x" * #X * X^-2))

-- Create a parser definition context.
local parser = grammar.new "C"

-- Pattern definitions start here.
local space = S "\r\n\f\t\v "
parser:define ("whitespace" , space^1)

-- Comments.
parser:define ("comment.line.c",  "//" * (1 - endline)^0 * newline^-1)
parser:define ("comment.block.c", "/*" * (1 - P "*/")^0 * "*/")

-- Character and string literals.
parser:define("string.character.c", "'" * ((1 - S "\\\r\n\f'") + escape) * "'")
parser:define("string.quoted.c", '"' * ((1 - S'\\\r\n\f"') + escape)^0 * '"')

-- Preprocessor directives.
parser:define ("meta.preprocessor.c", "#" * (1 - S "\r\n\f\\" + "\\" * (newline + 1))^0 * newline^-1)

-- Keywords.
parser:define ("keyword.control.c", parser:keywords [[
  break case continue default do else for goto if _Pragma return switch while
]])

parser:define ("keyword.operator.sizeof.c", parser:keywords "sizeof")

parser:define ("storage.type.c", parser:keywords [[
  asm __asm__ auto bool _bool char _Complex double enum float _Imaginary int
  long short signed struct typedef union unsigned void
]])

parser:define ("storage.modifier.c", parser:keywords [[
  const extern inline register restrict static volatile
]])

parser:define ("constant.language.c", parser:keywords [[
  NULL true false TRUE FALSE
]])

-- Support types.
parser:define ("support.type.sys-types.c", parser:keywords [[
  u_char u_short u_int u_long ushort uint u_quad_t quat_t qaddr_t caddr_t
  daddr_t dev_t fixpt_t blkcnt_t blksize_t gid_t in_addr_t in_port_t ino_t
  key_t mode_t nlink_t id_t pid_t off_t segsz_t swblk_t uid_t id_t clock_t
  size_t ssize_t time_t useconds_t suseconds_t
]])

parser:define ("support.type.pthread.c", parser:keywords [[
  pthread_attr_t pthread_cond_t pthread_condattr_t pthread_mutex_t
  pthread_mutexattr_t pthread_once_t pthread_rwlock_t pthread_rwlockattr_t
  pthread_t pthread_key_t
]])

parser:define ("support.type.stdint.c", parser:keywords [[
  int8_t int16_t int32_t int64_t uint8_t uint16_t uint32_t uint64_t
  int_least8_t int_least16_t int_least32_t int_least64_t uint_least8_t
  uint_least16_t uint_least32_t uint_least64_t int_fast8_t int_fast16_t
  int_fast32_t int_fast64_t uint_fast8_t uint_fast16_t uint_fast32_t
  uint_fast64_t intptr_t uintptr_t intmax_t uintmax_t
]])

-- Numbers (matched before operators because .1 is a number).
local int = (("0" * ((S "xX" * X^1) + O^1)) + D^1) * S "lL"^-2
local flt = ((D^1 * "." * D^0
            + D^0 * "." * D^1
            + D^1 * "e" * D^1) * S "fF"^-1)
            + D^1 * S "fF"
parser:define("constant.numeric.c", flt + int)

-- Operators (matched after comments because of conflict with slash/division).
parser:define("operator", P ">>=" + "<<=" + "--" + ">>" + ">=" + "/=" + "==" + "<="
    + "+=" + "<<" + "*=" + "++" + "&&" + "|=" + "||" + "!=" + "&=" + "-="
    + "^=" + "%=" + "->" + S ",)*%+&(-~/^]{}|.[>!?:=<;")

-- Identifiers.
parser:define ("identifier", I * (I + D)^0)

-- Define an `error' token kind that consumes one character and enables
-- the lexer to resume as a last resort for dealing with unknown input.
parser:define("error", 1)

return parser:compile()
