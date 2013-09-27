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

ZILE_PATH = $(abs_builddir)/lib/?.lua;$(abs_srcdir)/lib/?.lua

RM = rm


## ------------- ##
## Declarations. ##
## ------------- ##

clean_local =

include lib/zile/zile.mk
include lib/zmacs/zmacs.mk
include lib/zz/zz.mk
include tests/tests.mk

check-local: $(check_local)
clean-local: $(clean_local)

## Use a builtin rockspec build with root at $(srcdir)/lib
mkrockspecs_args = --module-dir $(srcdir)/lib


## ------------- ##
## Installation. ##
## ------------- ##

doc_DATA +=						\
	AUTHORS						\
	FAQ						\
	NEWS						\
	$(NOTHING_ELSE)


## ------------- ##
## Distribution. ##
## ------------- ##

gitlog_fix	= $(srcdir)/build-aux/git-log-fix
gitlog_args	= --amend=$(gitlog_fix) --since=2009-03-30

# Elide travis features.
_travis_yml	= $(NOTHING_ELSE)

EXTRA_DIST +=						\
	FAQ						\
	$(NOTHING_ELSE)


## ------------ ##
## Maintenance. ##
## ------------ ##

# Use dashes instead of lists when updating copyright headers
update_copyright_env = UPDATE_COPYRIGHT_USE_INTERVALS=1

# Set format of NEWS
old_NEWS_hash = 42b62d1dc98f4d243f36ed6047e2f473

FORCE:
