# Source Makefile.am
#
# Copyright (c) 1997-2012 Free Software Foundation, Inc.
#
# This file is part of GNU Zi.
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

doc_DATA += src/dotzi.sample

BUILT_SOURCES = src/loadlua.lua

bin_SCRIPTS = src/zi

src_zi_LUA =						\
	src/lib.lua					\
	src/astr.lua					\
	src/estr.lua					\
	src/history.lua					\
	src/eval.lua					\
	src/main.lua					\
	src/variables.lua				\
	src/basic.lua					\
	src/bind.lua					\
	src/buffer.lua					\
	src/bundle.lua					\
	src/completion.lua				\
	src/editfns.lua					\
	src/funcs.lua					\
	src/getkey.lua					\
	src/help.lua					\
	src/file.lua					\
	src/keycode.lua					\
	src/killring.lua				\
	src/line.lua					\
	src/macro.lua					\
	src/marker.lua					\
	src/minibuf.lua					\
	src/redisplay.lua				\
	src/registers.lua				\
	src/search.lua					\
	src/tbl_vars.lua				\
	src/undo.lua					\
	src/window.lua					\
	src/term_curses.lua				\
	src/term_minibuf.lua				\
	src/term_redisplay.lua

dist_pkgdata_DATA =					\
	$(src_zi_LUA)					\
	src/loadlua.lua					\
	src/default-bindings.lua

PRODUCTIONSOURCES =					\
	$(src_zi_LUA)					\
	$(top_srcdir)/src/zi.lua			\
	$(top_srcdir)/src/loadlua.lua			\
	$(top_srcdir)/src/Makefile.am			\
	$(top_srcdir)/src/default-bindings.lua		\
	$(top_srcdir)/Makefile.am $(top_srcdir)/configure.ac

src/loadlua.lua: src/Makefile.am src/loadlua.lua.in
	cp src/loadlua.lua.in $@
	for i in $(src_zi_LUA); do echo 'require "'`echo $$i | sed -e 's|^src/||;s|\\.lua$$||'`'"' >> $@; done

$(top_builddir)/src/zi: $(PRODUCTIONSOURCES) Makefile
	rm -f $@ $@.tmp
	$(inplace_edit) '$@.lua' >$@.tmp
	mv $@.tmp $@
	chmod +x $@
	$(top_builddir)/src/zi --version >/dev/null || rm $@

src/dotzi.sample: src/tbl_vars.lua build-aux/mkdotzi.lua
	PACKAGE="$(PACKAGE)" $(LUA_ENV) $(LUA) $(srcdir)/build-aux/mkdotzi.lua $(srcdir)/src/tbl_vars.lua

install-exec-hook:
	$(install_edit) '$(top_builddir)/src/zi.lua' >$@.tmp
	$(INSTALL_SCRIPT) $@.tmp $(DESTDIR)$(bindir)/zi
	rm -f $@.tmp

EXTRA_DIST +=						\
	$(src_zi_LUA)					\
	src/zi.lua.in					\
	src/loadlua.lua.in				\
	src/dotzi.sample

CLEANFILES +=						\
	src/zi						\
	src/zi.lua

DISTCLEANFILES +=					\
	$(BUILT_SOURCES)
