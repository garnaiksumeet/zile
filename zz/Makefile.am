# zz Makefile.am
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


## ------------ ##
## Environment. ##
## ------------ ##

ZZ_PATH = $(abs_srcdir)/zz/?.lua


## ------------- ##
## Declarations. ##
## ------------- ##

zzdatadir = $(datadir)/zz

zz_install_edit =					\
	$(install_edit)					\
	-e 's|@zzdatadir[@]|$(zzdatadir)|g'		\
	$(NOTHING_ELSE)

zz_inplace_edit = 					\
	$(inplace_edit)					\
	-e 's|@zzdatadir[@]|$(abs_top_srcdir)/zz|g'	\
	$(NOTHING_ELSE)


## ------ ##
## Build. ##
## ------ ##

doc_DATA += zz/dotzz.sample

bin_SCRIPTS += zz/zz

man_MANS += zz/zz.1

dist_zzdata_DATA =					\
	zz/callbacks.lua				\
	zz/commands.lua					\
	zz/emacs-bindings.lua				\
	zz/keymaps.lua					\
	zz/main.lua					\
	zz/tbl_vars.lua					\
	$(NOTHING_ELSE)

zz/zz: $(dist_zzdata_DATA) Makefile
	@rm -f $@ $@.tmp
	$(AM_V_GEN)$(zz_inplace_edit) '$@.lua' >'$@.tmp'
	$(AM_V_at)mv $@.tmp $@
	$(AM_V_at)chmod +x $@
	@$@ --version >$@.log || { echo $@ --version; cat $@.log; rm $@; }
	@rm -f $@.log

MKDOTZZ_ENV =						\
	PACKAGE='zz'					\
	LUA_PATH="$(abs_srcdir)/zz/?.lua;$(ZILE_PATH);$(LUA_PATH)"

zz/dotzz.sample: zz/tbl_vars.lua zz/mkdotzz.lua
	$(AM_V_GEN)PACKAGE='zz'				\
	LUA_PATH='$(ZZ_PATH);$(ZILE_PATH);$(LUA_PATH)'	\
	  $(LUA) $(srcdir)/zz/mkdotzz.lua > '$@'

zz/zz.1: $(srcdir)/zz/zz.1.in zz/Makefile.am config.status
	@test -d zz || mkdir zz
	$(AM_V_at)rm -f $@ $@.tmp
	$(AM_V_GEN)$(install_edit) '$(srcdir)/$@.in' >'$@.tmp'
	$(AM_V_at)mv '$@.tmp' '$@'

$(srcdir)/zz/zz.1.in: zz/man-extras zz/zz configure.ac
	@test -d zz || mkdir zz
## Exit gracefully if zz.1.in is not writeable, such as during distcheck!
	$(AM_V_GEN)if ( touch $@.w && rm -f $@.w; ) >/dev/null 2>&1; \
	then						\
	  builddir='$(builddir)'			\
	  $(srcdir)/build-aux/missing --run		\
	    $(HELP2MAN)					\
	      '--output=$@'				\
	      '--no-info'				\
	      '--name=Zmacs'				\
	      --include '$(srcdir)/zmacs/man-extras'	\
	      zz/zz;					\
	fi


## ------------- ##
## Installation. ##
## ------------- ##

install_exec_hooks += install-zz-hook
install-zz-hook:
	@$(zz_install_edit) zz/zz.lua >'$@.tmp'
	@echo $(INSTALL_SCRIPT) zz/zz $(DESTDIR)$(bindir)/zz
	@$(INSTALL_SCRIPT) $@.tmp $(DESTDIR)$(bindir)/zz
	@rm -f $@.tmp


## ------------- ##
## Distribution. ##
## ------------- ##

EXTRA_DIST +=						\
	zz/dotzz.sample					\
	zz/man-extras					\
	zz/mkdotzz.lua					\
	zz/zz.lua.in					\
	zz/zz.1.in					\
	$(NOTHING_ELSE)


## ------------ ##
## Maintenance. ##
## ------------ ##

CLEANFILES +=						\
	zz/zz						\
	zz/zz.1						\
	$(NOTHING_ELSE)

DISTCLEANFILES +=					\
	zz/zz.lua					\
	$(NOTHING_ELSE)

MAINTAINERCLEANFILES +=					\
	$(srcdir)/zz/zz.lua.in				\
	$(srcdir)/zz/zz.1.in				\
	$(NOTHING_ELSE)
