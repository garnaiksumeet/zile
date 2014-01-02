# Configuration for maintainer-makefile
#
# Copyright (c) 2011-2014 Free Software Foundation, Inc.
#
# This file is part of GNU Zile.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3, or (at your option)
# any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

# Don't check test outputs or diffs
VC_LIST_ALWAYS_EXCLUDE_REGEX = \.(output|diff)$$

# Allow errors to start with a capital (they are displayed on a
# separate line, interactively)
local-checks-to-skip = sc_error_message_uppercase

# Allow AM_V machinery for ZLC with AM_SILENT_RULES
_makefile_at_at_check_exceptions = '&& !/AM(_DEFAULT)?_V/'

define _sc_search_regexp_or_exclude
  files=$$($(VC_LIST_EXCEPT));						\
  if test -n "$$files"; then						\
    grep -nE "$$prohibit" $$files | grep -v -- '-- exclude from $@'	\
      && { msg="$$halt" $(_sc_say_and_exit) } || :;			\
  else :;								\
  fi || :;
endef

# Prohibit rvalues on LHS of a comparison in Lua.
sc_lua_prohibit_LHS_rvalue:
	@prohibit='if  *(false|nil|true|"[^"]*"|'"'[^']*'"'|[1-9][0-9]*) *[~=]=' \
	halt='found useless `"rhs" == lhs'\'' transposed comparison'	\
	  $(_sc_search_regexp_or_exclude)
