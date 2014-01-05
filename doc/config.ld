-- -*- lua -*-
project = "zile"
description = "Zile Implements Lua Editors"
boilerplate = true
dir = "."

file = {
  -- Classes
  "../lib/zile/Cons.lua",
  "../lib/zile/Set.lua",

  -- Modules
  "../lib/zile/zlisp.lua",
  "../lib/zmacs/eval.lua",
  "../lib/zz/eval.lua",
}

format = "markdown"
sort = true
