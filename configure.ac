dnl configure.ac
dnl
dnl Copyright (c) 1997-2014 Free Software Foundation, Inc.
dnl
dnl This file is part of GNU Zile.
dnl
dnl GNU Zile is free software; you can redistribute it and/or modify
dnl it under the terms of the GNU General Public License as published
dnl by the Free Software Foundation; either version 3, or (at your
dnl option) any later version.
dnl
dnl GNU Zile is distributed in the hope that it will be useful, but
dnl WITHOUT ANY WARRANTY; without even the implied warranty of
dnl MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
dnl General Public License for more details.
dnl
dnl You should have received a copy of the GNU General Public License
dnl along with GNU Zile; see the file COPYING.  If not, write to the
dnl Free Software Foundation, Fifth Floor, 51 Franklin Street, Boston,
dnl MA 02111-1301, USA.

AC_PREREQ([2.61])

dnl Initialise autoconf and automake
AC_INIT(Zile, 2.4.10, bug-zile@gnu.org)
AC_CONFIG_AUX_DIR([build-aux])
AM_INIT_AUTOMAKE([-Wall std-options])
m4_ifdef([AM_SILENT_RULES], [AM_SILENT_RULES([yes])])

dnl Checks for programs
gl_EARLY
AM_PROG_CC_C_O
PKG_PROG_PKG_CONFIG

dnl Extra warnings with GCC
AC_ARG_ENABLE([gcc-warnings],
  [AS_HELP_STRING([--enable-gcc-warnings],
                  [turn on lots of GCC warnings (for developers)])],
  [case $enableval in
     yes|no) ;;
     *)      AC_MSG_ERROR([bad value $enableval for gcc-warnings option]) ;;
   esac
   gl_gcc_warnings=$enableval],
  [gl_gcc_warnings=no]
)
if test "$gl_gcc_warnings" = yes; then
  dnl Set up the list of undesired warnings.
  nw=
  nw="$nw -Wsystem-headers"   # Don’t let system headers trigger warnings
  nw="$nw -Wundef"            # All compiler preprocessors support #if UNDEF
  nw="$nw -Wtraditional"      # All compilers nowadays support ANSI C
  nw="$nw -Wdeclaration-after-statement" # We require C99.
  nw="$nw -Wstrict-overflow"  # Use a lower level (see below).
  nw="$nw -Wconversion"       # These warnings usually don’t point to mistakes.
  nw="$nw -Wsign-conversion"  # Likewise.
  nw="$nw -Waggregate-return" # We do this on purpose.
  nw="$nw -Wbad-function-cast" # FIXME: We do this on purpose (non-pointer list elements).
  nw="$nw -Wtraditional-conversion" # Don't care.
  nw="$nw -Wpadded"           # Don't care.
  nw="$nw -Wc++-compat"       # Don't care.
  nw="$nw -Woverlength-strings" # Don't care.
  nw="$nw -Wmissing-format-attribute" # Don't care.
  nw="$nw -Wunreachable-code" # Seems buggy.

  gl_MANYWARN_ALL_GCC([warnings])

  dnl Enable all GCC warnings not in this list.
  gl_MANYWARN_COMPLEMENT([warnings], [$warnings], [$nw])
  for w in $warnings; do
    gl_WARN_ADD([$w])
  done

  dnl Add an extra warning
  gl_WARN_ADD([-Wstrict-overflow=1])
  dnl Add some more safety measures
  gl_WARN_ADD([-D_FORTIFY_SOURCE=2])
  gl_WARN_ADD([-fmudflap])

  # When compiling with GCC, prefer -isystem to -I when including system
  # include files, to avoid generating useless diagnostics for the files.
  ISYSTEM='-isystem '
else
  ISYSTEM='-I'
fi
AC_SUBST([ISYSTEM])

dnl Extra debugging
AC_ARG_ENABLE(debug,
  [AS_HELP_STRING([--enable-debug],
                  [include extra debugging code])],
  [case $enableval in
     yes|no) ;;
     *)      AC_MSG_ERROR([bad value $enableval for --enable-debug]) ;;
   esac],
  [])
if test "$enable_debug" = "yes"; then
  AC_DEFINE([DEBUG], 1, [Define this to include extra debugging code.])
fi

dnl help2man
dnl Set a value even if not found, so that an invocation via build-aux/missing works
AX_WITH_PROG([HELP2MAN], [help2man], [help2man])

dnl Code complexity reports
AC_PATH_PROG([PMCCABE], [pmccabe], [false])

dnl Valgrind
AC_ARG_ENABLE([valgrind],
  [AS_HELP_STRING([--enable-valgrind],
                  [use Valgrind to run tests])],
  [case $enableval in
     yes|no) ;;
     *)      AC_MSG_ERROR([bad value $enableval for --enable-valgrind]) ;;
   esac],
  [])
if test "$enable_valgrind" = "yes"; then
  AX_WITH_PROG([VALGRIND], [valgrind])
  if test -n "$VALGRIND"; then
    VALGRIND="$VALGRIND -q --error-exitcode=1"
  else
    AC_MSG_ERROR([can't find valgrind])
  fi
fi

dnl Checks for functions and headers
AC_HEADER_STDC
dnl If system lacks RE_PLAIN, force --with-included-regex
AC_MSG_CHECKING([whether system regex.h has RE_PLAIN])
AC_COMPILE_IFELSE(
  [AC_LANG_PROGRAM(
    [AC_INCLUDES_DEFAULT[
     #include <regex.h>
     ]],
    [[reg_syntax_t syn = RE_PLAIN;]])],
 [AC_MSG_RESULT([yes])],
 [AC_MSG_RESULT([no])
 with_included_regex=yes],
 dnl When crosscompiling, force included regex.
 [AC_MSG_RESULT([no])
 with_included_regex=yes])
gl_INIT

dnl Curses
AX_WITH_CURSES
if test "$ax_cv_curses" != "yes"; then
  AC_MSG_ERROR([cannot find curses])
fi
AC_ARG_VAR(CURSES_LIB, [linker flags for curses library])

dnl libgc (BDW garbage collector)
PKG_CHECK_MODULES([LIBGC],[bdw-gc >= 7.2])
AH_BOTTOM([
#ifdef DEBUG
# define malloc GC_debug_malloc
# define realloc GC_debug_realloc
# define free GC_debug_free
# define strdup GC_debug_strdup
# define strndup GC_debug_strndup
#else
# define malloc GC_malloc
# define realloc GC_realloc
# define free GC_free
# define strdup GC_strdup
# define strndup GC_strndup
#endif
#define calloc zile_calloc
])

dnl Emacs
AX_WITH_PROG([EMACSPROG], [emacs])
if test -n "$EMACSPROG"; then
  emacs_min_version=23.1
  emacs_version=`$EMACSPROG --version 2>&1 | head -n 1 | cut -d' ' -f3`
  AC_MSG_CHECKING([Emacs version $emacs_version >= $emacs_min_version])
  AX_COMPARE_VERSION(["$emacs_version"], [ge], [$emacs_min_version],
    [AC_MSG_RESULT([yes])],
    [AC_MSG_RESULT([no])
    unset EMACSPROG])
fi

dnl Perl
AX_WITH_PROG([PERL], [perl])
if test -z "$PERL"; then
  AC_MSG_FAILURE([cannot find perl])
fi

dnl Generate output
AC_CONFIG_HEADERS([config.h])
AC_CONFIG_FILES([Makefile lib/Makefile src/tbl_opts.h])
AC_OUTPUT
