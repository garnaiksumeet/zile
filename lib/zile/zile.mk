# Source Makefile.am
#
# Copyright (c) 1997-2013 Free Software Foundation, Inc.
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

dist_pkgdata_DATA =				\
	lib/zile/astr.lua			\
	lib/zile/bind.lua			\
	lib/zile/buffer.lua			\
	lib/zile/completion.lua			\
	lib/zile/editfns.lua			\
	lib/zile/estr.lua			\
	lib/zile/file.lua			\
	lib/zile/funcs.lua			\
	lib/zile/getkey.lua			\
	lib/zile/history.lua			\
	lib/zile/keycode.lua			\
	lib/zile/killring.lua			\
	lib/zile/lib.lua			\
	lib/zile/line.lua			\
	lib/zile/macro.lua			\
	lib/zile/marker.lua			\
	lib/zile/minibuf.lua			\
	lib/zile/redisplay.lua			\
	lib/zile/registers.lua			\
	lib/zile/search.lua			\
	lib/zile/term_curses.lua		\
	lib/zile/term_minibuf.lua		\
	lib/zile/term_redisplay.lua		\
	lib/zile/undo.lua			\
	lib/zile/version.lua			\
	lib/zile/window.lua			\
	$(NOTHING_ELSE)

EXTRA_DIST +=					\
	lib/zile/version.lua			\
	$(NOTHING_ELSE)
