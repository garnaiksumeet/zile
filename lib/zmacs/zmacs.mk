# zmacs Makefile.am
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


## ------------- ##
## Declarations. ##
## ------------- ##

zmacsdatadir = $(datadir)/zmacs
zmacscmdsdir = $(zmacsdatadir)/zlisp


## ------ ##
## Build. ##
## ------ ##

doc_DATA += doc/dotzmacs.sample

dist_bin_SCRIPTS += bin/zmacs

man_MANS += doc/zmacs.1

## $(srcdir) prefixes are required when passing $(dist_zmacscmds_DATA)
## to zlc in the build tree with a VPATH build, otherwise it fails to
## find them in $(builddir)/zmacs/commands/*.
dist_zmacscmds_DATA =					\
	$(srcdir)/lib/zmacs/zlisp/bind.zl		\
	$(srcdir)/lib/zmacs/zlisp/buffer.zl		\
	$(srcdir)/lib/zmacs/zlisp/edit.zl		\
	$(srcdir)/lib/zmacs/zlisp/file.zl		\
	$(srcdir)/lib/zmacs/zlisp/killring.zl		\
	$(srcdir)/lib/zmacs/zlisp/help.zl		\
	$(srcdir)/lib/zmacs/zlisp/line.zl		\
	$(srcdir)/lib/zmacs/zlisp/lisp.zl		\
	$(srcdir)/lib/zmacs/zlisp/macro.zl		\
	$(srcdir)/lib/zmacs/zlisp/marker.zl		\
	$(srcdir)/lib/zmacs/zlisp/minibuf.zl		\
	$(srcdir)/lib/zmacs/zlisp/move.zl		\
	$(srcdir)/lib/zmacs/zlisp/registers.zl		\
	$(srcdir)/lib/zmacs/zlisp/search.zl		\
	$(srcdir)/lib/zmacs/zlisp/undo.zl		\
	$(srcdir)/lib/zmacs/zlisp/variables.zl		\
	$(srcdir)/lib/zmacs/zlisp/window.zl		\
	$(NOTHING_ELSE)

dist_zmacsdata_DATA =					\
	lib/zmacs/default-bindings-el.lua		\
	lib/zmacs/callbacks.lua				\
	lib/zmacs/commands.lua				\
	lib/zmacs/keymaps.lua				\
	lib/zmacs/eval.lua				\
	lib/zmacs/main.lua				\
	lib/zmacs/zlisp.lua				\
	$(dist_zmacscmds_DATA)				\
	$(NOTHING_ELSE)

zmacs_zmacs_DEPS =					\
	Makefile					\
	lib/zmacs/zmacs.in				\
	$(dist_zmacsdata_DATA)				\
	$(NOTHING_ELSE)


# AM_SILENT_RULES pretty printing.
ZM_V_ZLC    = $(zm__v_ZLC_@AM_V@)
zm__v_ZLC_  = $(zm__v_ZLC_@AM_DEFAULT_V@)
zm__v_ZLC_0 = @echo "  ZLC     " $@;
zm__v_ZLC_1 =

lib/zmacs/commands.lua: $(dist_zmacscmds_DATA)
	@d=`echo '$@' |sed 's|/[^/]*$$||'`;			\
	test -d "$$d" || $(MKDIR_P) "$$d"
	$(ZM_V_ZLC)LUA_PATH='$(ZILE_PATH);$(LUA_PATH)'		\
	  $(LUA) $(srcdir)/lib/zmacs/zlc $(dist_zmacscmds_DATA) > $@

doc/dotzmacs.sample: lib/zmacs/mkdotzmacs.lua
	@d=`echo '$@' |sed 's|/[^/]*$$||'`;			\
	test -d "$$d" || $(MKDIR_P) "$$d"
	$(AM_V_GEN)PACKAGE='$(PACKAGE)'				\
	LUA_PATH='$(ZILE_PATH);$(LUA_PATH)'			\
	  $(LUA) $(srcdir)/lib/zmacs/mkdotzmacs.lua > '$@'

doc/zmacs.1: lib/zmacs/man-extras lib/zmacs/help2man-wrapper $(dist_zmacsdata_DATA)
	@d=`echo '$@' |sed 's|/[^/]*$$||'`;			\
	test -d "$$d" || $(MKDIR_P) "$$d"
## Exit gracefully if zmacs.1.in is not writeable, such as during distcheck!
	$(AM_V_GEN)if ( touch $@.w && rm -f $@.w; ) >/dev/null 2>&1; \
	then							\
	  builddir='$(builddir)'				\
	  $(srcdir)/build-aux/missing --run			\
	    $(HELP2MAN)						\
	      '--output=$@'					\
	      '--no-info'					\
	      '--name=Zmacs'					\
	      --include '$(srcdir)/lib/zmacs/man-extras'	\
	      '$(srcdir)/lib/zmacs/help2man-wrapper';		\
	fi



## --------------------------- ##
## Interactive help resources. ##
## --------------------------- ##

# There's no portable way to install and then access from zmacs
# plain text resources, so we convert them to Lua modules here.

zmacsdocdatadir = $(zmacsdatadir)/doc

dist_zmacsdocdata_DATA =					\
	$(srcdir)/lib/zmacs/doc/COPYING.lua			\
	$(srcdir)/lib/zmacs/doc/FAQ.lua				\
	$(srcdir)/lib/zmacs/doc/NEWS.lua			\
	$(NOTHING_ELSE)

$(srcdir)/lib/zmacs/doc:
	@test -d '$@' || $(MKDIR_P) '$@'

$(dist_zmacsdocdata_DATA): $(srcdir)/lib/zmacs/doc
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



## ----------- ##
## Test suite. ##
## ----------- ##


CD_ZMACSTESTDIR	= abs_srcdir=`$(am__cd) $(srcdir) && pwd`; cd $(zmacstestsdir)

zmacstestsdir	= lib/zmacs/tests
zmacspackage_m4	= $(zmacstestsdir)/package.m4
zmacstestsuite	= $(zmacstestsdir)/testsuite

ZMACSTESTSUITE	= lib/zmacs/tests/testsuite
ZMACSTESTSUITE_AT	= $(zmacstestsdir)/testsuite.at \
		  $(zmacstestsdir)/message.at \
		  $(zmacstestsdir)/write-file.at \
		  $(NOTHING_ELSE)

EXTRA_DIST	+= $(zmacstestsuite) $(ZMACSTESTSUITE_AT) $(zmacspackage_m4)

ZMACSTESTS_ENVIRONMENT = ZMACS="$(abs_builddir)/lib/zmacs/zmacs"

$(zmacstestsuite): $(zmacspackage_m4) $(ZMACSTESTSUITE_AT) Makefile.am
	$(AM_V_GEN)$(AUTOTEST) -I '$(srcdir)' -I '$(zmacstestsdir)' \
	  $(ZMACSTESTSUITE_AT) -o '$@'

$(zmacspackage_m4): $(dotversion) lib/zmacs/zmacs.mk
	$(AM_V_GEN){ \
	  echo '# Signature of the current package.'; \
	  echo 'm4_define([AT_PACKAGE_NAME],      [$(PACKAGE_NAME)])'; \
	  echo 'm4_define([AT_PACKAGE_TARNAME],   [$(PACKAGE_TARNAME)])'; \
	  echo 'm4_define([AT_PACKAGE_VERSION],   [$(PACKAGE_VERSION)])'; \
	  echo 'm4_define([AT_PACKAGE_STRING],    [$(PACKAGE_STRING)])'; \
	  echo 'm4_define([AT_PACKAGE_BUGREPORT], [$(PACKAGE_BUGREPORT)])'; \
	  echo 'm4_define([AT_PACKAGE_URL],       [$(PACKAGE_URL)])'; \
	} > '$@'

$(zmacstestsdir)/atconfig: config.status
	$(AM_V_GEN)$(SHELL) config.status '$@'

DISTCLEANFILES	+= $(zmacstestsdir)/atconfig

# Hook the test suite into the check rule
check_local += zmacs-check-local
zmacs-check-local: $(zmacstestsdir)/atconfig $(zmacstestsuite)
	$(AM_V_at)$(CD_ZMACSTESTDIR); \
	CONFIG_SHELL='$(SHELL)' '$(SHELL)' "$$abs_srcdir/$(ZMACSTESTSUITE)" \
	  $(ZMACSTESTS_ENVIRONMENT) $(BUILDCHECK_ENVIRONMENT) $(ZMACSTESTSUITEFLAGS)

# Remove any file droppings left behind by testsuite.
clean_local += zmacs-clean-local
zmacs-clean-local:
	$(CD_ZMACSTESTDIR); \
	test -f "$$abs_srcdir/$(ZMACSTESTSUITE)" && \
	  '$(SHELL)' "$$abs_srcdir/$(ZMACSTESTSUITE)" --clean || :


## ------------- ##
## Distribution. ##
## ------------- ##

EXTRA_DIST +=						\
	doc/dotzmacs.sample				\
	lib/zmacs/commands.lua				\
	lib/zmacs/help2man-wrapper			\
	lib/zmacs/man-extras				\
	lib/zmacs/mkdotzmacs.lua			\
	lib/zmacs/zlc					\
	lib/zmacs/zmacs.in				\
	$(NOTHING_ELSE)


## ------------ ##
## Maintenance. ##
## ------------ ##

CLEANFILES +=						\
	doc/zmacs.1					\
	$(NOTHING_ELSE)

MAINTAINERCLEANFILES +=					\
	$(srcdir)/lib/zmacs/commands.lua		\
	$(srcdir)/lib/zmacs/zmacs.1.in			\
	$(dist_zmacsdocdata_DATA)			\
	$(NOTHING_ELSE)
