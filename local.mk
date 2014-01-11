# Top-level Makefile.am
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


## ------------ ##
## Environment. ##
## ------------ ##

ZILE_PATH = $(abs_builddir)/lib/?.lua;$(abs_srcdir)/lib/?.lua

RM = rm


## ---------- ##
## Bootstrap. ##
## ---------- ##

old_NEWS_hash = 42b62d1dc98f4d243f36ed6047e2f473

update_copyright_env = \
	UPDATE_COPYRIGHT_USE_INTERVALS=1 \
	UPDATE_COPYRIGHT_FORCE=1


## ------------- ##
## Declarations. ##
## ------------- ##

classesdir		= $(docdir)/classes
modulesdir		= $(docdir)/modules

dist_doc_DATA		=
dist_classes_DATA	=
dist_modules_DATA	=
ldoc_DEPS		=

clean_local		=
install_exec_hook	=

include lib/zile/zile.mk
include lib/zmacs/zmacs.mk
include lib/zz/zz.mk
include tests/tests.mk

check-local: $(check_local)
clean-local: $(clean_local)
install-exec-hook: $(install_exec_hook)

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
	doc/config.ld					\
	$(NOTHING_ELSE)



## -------------- ##
## Documentation. ##
## -------------- ##

dist_doc_DATA +=				\
	$(srcdir)/doc/index.html		\
	$(srcdir)/doc/ldoc.css			\
	$(NOTHING_ELSE)

dist_classes_DATA +=				\
	$(srcdir)/doc/classes/zile.Cons.html	\
	$(srcdir)/doc/classes/zile.Set.html	\
	$(srcdir)/doc/classes/zile.Symbol.html	\
	$(NOTHING_ELSE)

dist_modules_DATA +=				\
	$(srcdir)/doc/modules/zile.zlisp.html	\
	$(srcdir)/doc/modules/zmacs.eval.html	\
	$(srcdir)/doc/modules/zz.eval.html	\
	$(NOTHING_ELSE)

$(dist_doc_DATA) $(dist_classes_DATA) $(dist_modules_DATA): $(ldoc_DEPS)
	cd $(srcdir) && $(LDOC) -c doc/config.ld .
