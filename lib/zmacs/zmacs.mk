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
zmacscmdsdir = $(zmacsdatadir)/commands


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
	$(srcdir)/lib/zmacs/commands/bind.zl		\
	$(srcdir)/lib/zmacs/commands/buffer.zl		\
	$(srcdir)/lib/zmacs/commands/edit.zl		\
	$(srcdir)/lib/zmacs/commands/file.zl		\
	$(srcdir)/lib/zmacs/commands/killring.zl	\
	$(srcdir)/lib/zmacs/commands/help.zl		\
	$(srcdir)/lib/zmacs/commands/line.zl		\
	$(srcdir)/lib/zmacs/commands/lisp.zl		\
	$(srcdir)/lib/zmacs/commands/macro.zl		\
	$(srcdir)/lib/zmacs/commands/marker.zl		\
	$(srcdir)/lib/zmacs/commands/minibuf.zl		\
	$(srcdir)/lib/zmacs/commands/move.zl		\
	$(srcdir)/lib/zmacs/commands/registers.zl	\
	$(srcdir)/lib/zmacs/commands/search.zl		\
	$(srcdir)/lib/zmacs/commands/undo.zl		\
	$(srcdir)/lib/zmacs/commands/variables.zl	\
	$(srcdir)/lib/zmacs/commands/window.zl		\
	$(NOTHING_ELSE)

dist_zmacsdata_DATA =					\
	lib/zmacs/default-bindings-el.lua		\
	lib/zmacs/callbacks.lua				\
	lib/zmacs/commands.lua				\
	lib/zmacs/keymaps.lua				\
	lib/zmacs/eval.lua				\
	lib/zmacs/main.lua				\
	lib/zmacs/variables.lua				\
	lib/zmacs/zlisp.lua				\
	$(dist_zmacscmds_DATA)				\
	$(NOTHING_ELSE)

zmacs_zmacs_DEPS =					\
	Makefile					\
	lib/zmacs/zmacs.in				\
	$(nodist_zmacsdata_DATA)			\
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

RM = rm

doc/dotzmacs.sample: lib/zmacs/variables.lua lib/zmacs/mkdotzmacs.lua
	@d=`echo '$@' |sed 's|/[^/]*$$||'`;			\
	test -d "$$d" || $(MKDIR_P) "$$d"
	$(AM_V_GEN)PACKAGE='$(PACKAGE)'				\
	LUA_PATH='$(ZILE_PATH);$(LUA_PATH)'			\
	  $(LUA) $(srcdir)/lib/zmacs/mkdotzmacs.lua > '$@'

doc/zmacs.1: lib/zmacs/man-extras lib/zmacs/help2man-wrapper configure.ac
	@d=`echo '$@' |sed 's|/[^/]*$$||'`;			\
	test -d "$$d" || $(MKDIR_P) "$$d"
## Exit gracefully if zmacs.1.in is not writeable, such as during distcheck!
	$(AM_V_GEN)if ( touch $@.w && rm -f $@.w; ) >/dev/null 2>&1; \
	then						\
	  builddir='$(builddir)'			\
	  $(srcdir)/build-aux/missing --run		\
	    $(HELP2MAN)					\
	      '--output=$@'				\
	      '--no-info'				\
	      '--name=Zmacs'				\
	      --include '$(srcdir)/lib/zmacs/man-extras'	\
	      '$(srcdir)/lib/zmacs/help2man-wrapper';	\
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


CD_TESTDIR	= abs_srcdir=`$(am__cd) $(srcdir) && pwd`; cd $(tests_dir)

tests_dir	= lib/zmacs/tests
package_m4	= $(tests_dir)/package.m4
testsuite	= $(tests_dir)/testsuite

TESTSUITE	= lib/zmacs/tests/testsuite
TESTSUITE_AT	= $(tests_dir)/testsuite.at \
		  $(tests_dir)/message.at \
		  $(tests_dir)/write-file.at \
		  $(NOTHING_ELSE)

EXTRA_DIST	+= $(testsuite) $(TESTSUITE_AT) $(package_m4)

TESTS_ENVIRONMENT = ZMACS="$(abs_builddir)/lib/zmacs/zmacs"

$(testsuite): $(package_m4) $(TESTSUITE_AT) Makefile.am
	$(AM_V_GEN)$(AUTOTEST) -I '$(srcdir)' -I '$(tests_dir)' \
	  $(TESTSUITE_AT) -o '$@'

$(package_m4): $(dotversion) lib/zmacs/zmacs.mk
	$(AM_V_GEN){ \
	  echo '# Signature of the current package.'; \
	  echo 'm4_define([AT_PACKAGE_NAME],      [$(PACKAGE_NAME)])'; \
	  echo 'm4_define([AT_PACKAGE_TARNAME],   [$(PACKAGE_TARNAME)])'; \
	  echo 'm4_define([AT_PACKAGE_VERSION],   [$(PACKAGE_VERSION)])'; \
	  echo 'm4_define([AT_PACKAGE_STRING],    [$(PACKAGE_STRING)])'; \
	  echo 'm4_define([AT_PACKAGE_BUGREPORT], [$(PACKAGE_BUGREPORT)])'; \
	  echo 'm4_define([AT_PACKAGE_URL],       [$(PACKAGE_URL)])'; \
	} > '$@'

$(tests_dir)/atconfig: config.status
	$(AM_V_GEN)$(SHELL) config.status '$@'

DISTCLEANFILES	+= $(tests_dir)/atconfig

# Hook the test suite into the check rule
check_local += zmacs-check-local
zmacs-check-local: $(tests_dir)/atconfig $(testsuite)
	$(AM_V_at)$(CD_TESTDIR); \
	CONFIG_SHELL='$(SHELL)' '$(SHELL)' "$$abs_srcdir/$(TESTSUITE)" \
	  $(TESTS_ENVIRONMENT) $(BUILDCHECK_ENVIRONMENT) $(TESTSUITEFLAGS)

# Remove any file droppings left behind by testsuite.
clean-local:
	$(CD_TESTDIR); \
	test -f "$$abs_srcdir/$(TESTSUITE)" && \
	  '$(SHELL)' "$$abs_srcdir/$(TESTSUITE)" --clean || :


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
	bin/zmacs					\
	doc/zmacs.1					\
	$(NOTHING_ELSE)

MAINTAINERCLEANFILES +=					\
	$(srcdir)/lib/zmacs/commands.lua		\
	$(srcdir)/lib/zmacs/zmacs.1.in			\
	$(dist_zmacsdocdata_DATA)			\
	$(NOTHING_ELSE)
