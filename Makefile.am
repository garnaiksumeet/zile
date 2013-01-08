# Top-level Makefile.am
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

LUA_PATH ?= ;
ZILE_PATH = $(abs_srcdir)/src/?.lua


## ---------- ##
## Bootstrap. ##
## ---------- ##

ACLOCAL_AMFLAGS = -I m4


## ------------- ##
## Declarations. ##
## ------------- ##

CLEANFILES		=
DISTCLEANFILES		=
EXTRA_DIST		=
MAINTAINERCLEANFILES	=
NOTHING_ELSE		=

bin_SCRIPTS		=
doc_DATA		=
install_exec_hooks	=
man_MANS		=

install_edit = sed					\
	-e 's|@pkgdatadir[@]|$(pkgdatadir)|g'		\
	-e 's|@pkgdocdir[@]|$(docdir)|g'		\
	-e 's|@LUA[@]|$(LUA)|g'				\
	$(NOTHING_ELSE)

inplace_edit = sed					\
	-e 's|@pkgdatadir[@]|$(abs_top_srcdir)/src|g'	\
	-e 's|@pkgdocdir[@]|$(abs_top_srcdir)|g'	\
	-e 's|@LUA[@]|$(LUA)|g'				\
	$(NOTHING_ELSE)

include src/Makefile.am
include zmacs/Makefile.am
include zz/Makefile.am
include tests/Makefile.am


## ------------- ##
## Installation. ##
## ------------- ##

doc_DATA +=						\
	AUTHORS						\
	FAQ						\
	NEWS						\
	$(NOTHING_ELSE)

install-exec-hook: $(install_exec_hooks)


## ------------- ##
## Distribution. ##
## ------------- ##

gitlog_to_changelog	= $(srcdir)/build-aux/gitlog-to-changelog
git_log_fix		= $(srcdir)/build-aux/git-log-fix

dist-hook: ChangeLog
ChangeLog: FORCE
	$(AM_V_GEN)if test -d '$(srcdir)/.git'; then	\
	  $(gitlog_to_changelog) --amend=$(git_log_fix)	\
	      --since=2009-03-30 > '$@T';		\
	  rm -f '$@'; mv '$@T' '$@';			\
	fi

EXTRA_DIST +=						\
	FAQ						\
	GNUmakefile					\
	maint.mk					\
	$(NOTHING_ELSE)

distcheck-hook: syntax-check


## ------------ ##
## Maintenance. ##
## ------------ ##

FORCE:
