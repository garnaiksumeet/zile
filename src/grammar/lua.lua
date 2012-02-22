-- Lexer for Lua 5.1 source code powered by LPeg.

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

local D = R "09"
local I = R ("AZ", "az", "\127\255") + "_"
local W = I * (I + D)^0
local B = -(I + D) -- word boundary


-- Create a parser definition context.
local parser = grammar.new "Lua"


-- Pattern definitions start here.
parser:define ("whitespace", grammar.space^1)

local math = P "math." * (P "pi" + "huge")
parser:define ("constant.language.lua",
   (P "true" + "false" + "nil" + "_G" + "_VERSION" + math) * B)

-- Pattern for long strings and long comments.
local longstring = #(P "[[" + (P "[" * P "="^0 *  "[")) * P (function (input, index)
  local level = input:match ("^%[(=*)%[", index)
  if level then
    local _, last = input:find ("]" .. level .. "]", index, true)
    if last then return last + 1 end
  end
end)

-- String literals.
parser:define ("string.quoted.single.lua", P "'" * ((1 - S "'\r\n\f\\") + (P "\\" * 1))^0 * "'")
parser:define ("string.quoted.double.lua", P '"' * ((1 - S '"\r\n\f\\') + (P "\\" * 1))^0 * '"')
parser:define ("string.quoted.other.multiline.lua", longstring)

-- Comments.
local eol  = P "\r\n" + "\n"
local line = (1 - S "\r\n\f")^0 * eol^-1
local soi  = P (function (_, i) return i == 1 and i end)
parser:define ("comment.line.octothorpe.lua",  soi * "#!" * line)
parser:define ("comment.line.double-dash.lua", P "--" * line)
parser:define ("comment.block.lua",            P "--" * longstring)

-- Numbers.
local sign        = S "+-"^-1
local decimal     = D^1
local hexadecimal = P "0" * S "xX" * R ("09", "AF", "af")^1
local float       = D^1 * P "." * D^0 + P "." * D^1
local maybeexp    = (float + decimal) * (S "eE" * sign * D^1)^-1
parser:define ("constant.numeric.lua", hexadecimal + maybeexp)

-- Function declarations.
local L, T, V = grammar.literal, grammar.terminal, lpeg.V
local C = function (...) return ... end
local elipsis  = "constant.language.elipsis"
local funcname = "entity.name.function"
local param    = "identifier.parameter"
local kwfunc   = "keyword.control.function"
local kwequals = "keyword.operator.equals"
parser:define ("meta.function.lua", P{
  "INIT";
  INIT       = V"FUNCDECL" + V"FUNCASSIGN" / C,

  FUNCASSIGN = V(funcname) * V(kwequals) * V(kwfunc) * V"PARMS" / C,
  FUNCDECL   = V(kwfunc) * V(funcname) * V"PARMS" / C,
  PARMS      = L"(" * V"PARMLIST" * L")" / C,
  PARMLIST   = V"NAMELIST" + V(elipsis) / C,
  NAMELIST   = V(param) * (L"," * V(param))^0 * (L"," * V(elipsis))^-1 / C,

  [kwfunc]   = T(kwfunc, P"function") / C,
  [funcname] = T(funcname, W) / C,
  [param]    = T(param, W) / C,
  [elipsis]  = T(elipsis, P"...") / C,
  [kwequals] = T(kwequals, P"=") / C,
})

-- Operators (matched after comments because of conflict with minus).
parser:define ("keyword.operator", P "not" + "..." + "and" + ".." + "~="
  + "==" + ">=" + "<=" + "or" + S "]{=>^[<;)*(%}+-:,/.#")

-- Keywords.
parser:define ("keyword.control.lua", parser:keywords [[
  break do else elseif end for function if in repeat return then until while
]])
parser:define("storage.modifier.lua", parser:keywords "local")

-- Support functions.
local lcoroutine = P "coroutine." * parser:keywords [[
  create resume running status wrap yield
]]
local ldebug = P "debug." * parser:keywords [[
  getfenv gethook getinfo getlocal getmetatable getregistry getupvalue
  setfenv sethook setlocal setmetatable setupvalue traceback
]]
local lio = P "io." * parser:keywords [[
  close flush input lines open output popen read tmpfile type write
]]
local lmath = P "math." * parser:keywords [[
  abs acos asin atan atan2 ceil cos cosh deg exp floor fmod frexp ldexp log
  log10 max min modf pow rad random randomseed sin sinh sqrt tan tanh
]]
local los = P "os." * parser:keywords [[
  clock date difftime execute exit getenv remove rename setlocale time tmpname
]]
local lpackage = P "package." * parser:keywords [[
  cpath loaded loadlib path preload seeall
]]
local lstring = P "string." * parser:keywords [[
  byte char dump find format gmatch gsub len lower match rep reverse sub upper
]]
local ltable = P "table." * parser:keywords [[
  concat insert maxn remove sort
]]
parser:define ("support.function.library.lua", lcoroutine + ldebug + lio + lmath
  + los + lpackage + lstring + ltable)
parser:define ("support.function.lua", parser:keywords [[
  assert collectgarbage dofile error getfenv getmetatable ipairs loadfile
  loadstring module next pairs pcall print rawequal rawget rawset require
  select setfenv setmetatable tonumber tostring type unpack xpcall
]])

-- Identifiers
parser:define ("identifier", I * (I + D)^0)

-- Define an `error' token kind that consumes one character and enables
-- the parser to resume as a last resort for dealing with unknown input.
parser:define ("error", 1)

-- Compile the final LPeg pattern to match any single token and return the
-- table containing the various definitions that make up the Lua parser.
return parser:compile ()
