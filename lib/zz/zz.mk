# zz Makefile.am
#
# Copyright (c) 1997-2014 Free Software Foundation, Inc.
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


## ------------- ##
## Declarations. ##
## ------------- ##

zzdatadir = $(datadir)/zz
zzcmdsdir = $(zzdatadir)/commands


## ------ ##
## Build. ##
## ------ ##

doc_DATA += doc/dotzz.sample

dist_bin_SCRIPTS += bin/zz

man_MANS += doc/zz.1

dist_zzcmds_DATA =					\
	lib/zz/commands/bind.lua			\
	lib/zz/commands/buffer.lua			\
	lib/zz/commands/edit.lua			\
	lib/zz/commands/file.lua			\
	lib/zz/commands/killring.lua			\
	lib/zz/commands/help.lua			\
	lib/zz/commands/line.lua			\
	lib/zz/commands/lua.lua				\
	lib/zz/commands/macro.lua			\
	lib/zz/commands/marker.lua			\
	lib/zz/commands/minibuf.lua			\
	lib/zz/commands/move.lua			\
	lib/zz/commands/registers.lua			\
	lib/zz/commands/search.lua			\
	lib/zz/commands/undo.lua			\
	lib/zz/commands/variables.lua			\
	lib/zz/commands/window.lua			\
	$(NOTHING_ELSE)

dist_zzdata_DATA =					\
	lib/zz/default-bindings.lua			\
	lib/zz/callbacks.lua				\
	lib/zz/commands.lua				\
	lib/zz/keymaps.lua				\
	lib/zz/eval.lua					\
	lib/zz/main.lua					\
	$(dist_zzcmds_DATA)				\
	$(NOTHING_ELSE)

zz_zz_DEPS =						\
	Makefile					\
	lib/zz/zz.in					\
	$(dist_zzdata_DATA)				\
	$(NOTHING_ELSE)


doc/dotzz.sample: lib/zz/mkdotzz.lua
	@d=`echo '$@' |sed 's|/[^/]*$$||'`;			\
	test -d "$$d" || $(MKDIR_P) "$$d"
	$(AM_V_GEN)PACKAGE='$(PACKAGE)'				\
	LUA_PATH='$(ZILE_PATH);$(LUA_PATH)'			\
	  $(LUA) $(srcdir)/lib/zz/mkdotzz.lua > '$@'

doc/zz.1: lib/zz/man-extras $(dist_zzdata_DATA)
	@d=`echo '$@' |sed 's|/[^/]*$$||'`;			\
	test -d "$$d" || $(MKDIR_P) "$$d"
## Exit gracefully if zz.1.in is not writeable, such as during distcheck!
	$(AM_V_GEN)if ( touch $@.w && rm -f $@.w; ) >/dev/null 2>&1; \
	then							\
	  builddir='$(builddir)'				\
	  $(srcdir)/build-aux/missing --run			\
	    $(HELP2MAN)						\
	      '--output=$@'					\
	      '--no-info'					\
	      '--name=Zz'					\
	      --include '$(srcdir)/lib/zz/man-extras'		\
	      'lib/zz/zz';					\
	fi



## --------------------------- ##
## Interactive help resources. ##
## --------------------------- ##

# There's no portable way to install and then access from zz
# plain text resources, so we convert them to Lua modules here.

zzdocdatadir = $(zzdatadir)/doc

dist_zzdocdata_DATA =					\
	$(srcdir)/lib/zz/doc/COPYING.lua			\
	$(srcdir)/lib/zz/doc/FAQ.lua				\
	$(srcdir)/lib/zz/doc/NEWS.lua			\
	$(NOTHING_ELSE)

$(srcdir)/lib/zz/doc:
	@test -d '$@' || $(MKDIR_P) '$@'

$(dist_zzdocdata_DATA): $(srcdir)/lib/zz/doc
## Exit gracefully if target is not writeable, such as during distcheck!
	$(AM_V_GEN)if ( touch $@.w && rm -f $@.w; ) >/dev/null 2>&1; \
	then							\
	  {							\
	    src=`echo '$@' |sed -e 's|^.*/||' -e 's|\.lua$$||'`;\
	    echo 'return [==[';					\
	    cat "$(srcdir)/$$src";				\
	    echo ']==]';					\
	  } > '$@';						\
	fi



## -------------- ##
## Documentation. ##
## -------------- ##

ldoc_DEPS += $(dist_zzdata_DATA)


## ------------- ##
## Installation. ##
## ------------- ##

install_exec_hook += zz-install-exec-hook
zz-install-exec-hook:
	sed -e 's|@datadir[@]|$(datadir)|g' $(srcdir)/bin/zz >.zzT
	$(INSTALL_SCRIPT) .zzT $(DESTDIR)$(bindir)/zz
	rm -f .zzT


## ------------- ##
## Distribution. ##
## ------------- ##

EXTRA_DIST +=						\
	doc/dotzz.sample				\
	lib/zz/commands.lua				\
	lib/zz/man-extras				\
	lib/zz/mkdotzz.lua				\
	lib/zz/zz.in					\
	$(NOTHING_ELSE)


## ------------ ##
## Maintenance. ##
## ------------ ##

CLEANFILES +=						\
	doc/zz.1					\
	$(NOTHING_ELSE)

MAINTAINERCLEANFILES +=					\
	$(srcdir)/lib/zz/zz.1.in			\
	$(dist_zzdocdata_DATA)				\
	$(NOTHING_ELSE)
