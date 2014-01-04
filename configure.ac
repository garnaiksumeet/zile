dnl configure.ac
dnl
dnl Copyright (c) 1997-2014 Free Software Foundation, Inc.
dnl
dnl This file is part of GNU Zile.
dnl
dnl This program is free software; you can redistribute it and/or modify
dnl it under the terms of the GNU General Public License as published
dnl by the Free Software Foundation; either version 3, or (at your
dnl option) any later version.
dnl
dnl This program is distributed in the hope that it will be useful, but
dnl WITHOUT ANY WARRANTY; without even the implied warranty of
dnl MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
dnl General Public License for more details.
dnl
dnl You should have received a copy of the GNU General Public License
dnl along with this program.  If not, see <http://www.gnu.org/licenses/>.

AC_PREREQ([2.61])

dnl Initialise autoconf and automake
AC_INIT([Zile], [4], [bug-zile@gnu.org])
AC_CONFIG_AUX_DIR([build-aux])
AC_CONFIG_MACRO_DIRS([m4])

AS_BOX([Configuring AC_PACKAGE_TARNAME AC_PACKAGE_VERSION])
echo

AM_INIT_AUTOMAKE([-Wall std-options])
m4_ifdef([AM_SILENT_RULES], [AM_SILENT_RULES([yes])])

dnl Lua 5.2
AX_PROG_LUA([5.2])

dnl help2man
AC_PATH_PROG([HELP2MAN], [help2man], [false])

dnl Emacs >= 23.1 (optional)
AC_PATH_PROG([EMACSPROG], [emacs])
if test -n "$EMACSPROG"; then
  emacs_min_version=23.1
  emacs_version=$($EMACSPROG --version 2>&1 | head -n 1 | cut -d' ' -f3)
  AC_MSG_CHECKING([Emacs version $emacs_version >= $emacs_min_version])
  AX_COMPARE_VERSION([$emacs_version], [ge], [$emacs_min_version],
    [AC_MSG_RESULT([yes])],
    [AC_MSG_RESULT([no])
    unset EMACSPROG])
fi

AC_PROG_SED
AC_PROG_EGREP

dnl Generate output
SS_CONFIG_TRAVIS
AC_CONFIG_FILES([Makefile lib/zile/version.lua])
AC_CONFIG_FILES([lib/zmacs/zmacs], [chmod +x lib/zmacs/zmacs])
AC_CONFIG_FILES([lib/zz/zz], [chmod +x lib/zz/zz])
AC_OUTPUT
