# GNU Zile

GNU Zile is free software, licensed under the GNU GPL.

Copyright (c) 1997-2014 Free Software Foundation, Inc.

**Copying and distribution of this file, with or without modification,
are permitted in any medium without royalty provided the copyright
notice and this notice are preserved.**


## INTRODUCTION

GNU Zile (_Zile Implements Lua Editors_) is a text editor development
kit, so that you can (relatively) quickly develop your own ideal text
editor without reinventing the wheel for many of the common algorithms
and structures needed to do so.

It comes with an example implementation of a lightweight [Emacs][]
clone, called Zmacs. Every Emacs user should feel at home with Zmacs.
Zmacs is aimed at small footprint systems and quick editing sessions
(it starts up and shuts down instantly).

Zile and Zmacs are written in Lua 5.2 using POSIX APIs, and hence
requires a Lua 5.2 runtime and a few additional Lua modules:

 * [Lua-stdlib][]
 * [lrexlib][] the `rex_gnu` module must be built
 * [luaposix][] the curses module must be built
 * [alien][]

For exact version dependencies, see `require_version` statments in
`bin/zmacs`. These are most easily installed using [LuaRocks][].

 [alien]:      http://mascarenhas.github.io/alien/
 [emacs]:      http://www.gnu.org/s/emacs
 [gnulib]:     http://www.gnu.org/s/gnulib
 [lrexlib]:    http://rrthomas.github.io/lrexlib/
 [lua-stdlib]: http://rrthomasgithub.io/lua-stdlib/
 [luarocks]:   http://www.luarocks.org/


## Source Layout

 * See file [AUTHORS][] for the names of maintainers past and present.
 * See file [COPYING][] for copying conditions.
 * See file [FAQ][] for a selection of a Frequently Answered Questions.
 * See file [INSTALL][] for generic compilation and installation
   instructions.
 * See file [NEWS][] for a list of major changes in each Zile release.
 * See file [THANKS][] for a list of important contributors.

The rest of the files in the top-level directory are part of the
[Autotools][] build system used to compile and install Zile and Zmacs.

 * Directory [build-aux][] contains helper scripts used to build Zile.
 * Directory [doc][] contains files used to create Zile's documentation.
 * Directory [m4][] contains a mixture of [gnulib][] supplied and Zile-
   specific macros for rebuilding the `configure' script.
 * Directory [lib][] contains the source code used to build Zile, and
   the other editors that use it.

 [authors]:   http://git.savannah.gnu.org/cgit/zile.git/tree/AUTHORS
 [autotools]: http://sourceware.org/autobook/
 [build-aux]: http://git.savannah.gnu.org/cgit/zile.git/tree/build-aux?h=release
 [copying]:   http://git.savannah.gnu.org/cgit/zile.git/tree/COPYING
 [doc]:       http://git.savannah.gnu.org/cgit/zile.git/tree/doc?h=release
 [faq]:       http://git.savannah.gnu.org/cgit/zile.git/tree/FAQ
 [gnulib]:    http://www.gnu.org/s/gnulib
 [install]:   http://git.savannah.gnu.org/cgit/zile.git/tree/INSTALL?h=release
 [lib]:       http://git.savannah.gnu.org/cgit/zile.git/tree/lib
 [m4]:        http://git.savannah.gnu.org/cgit/zile.git/tree/m4?h=release


## Web Pages

 * There is a [GNU Zile home page][Zile] with information about Zile.
 * GNU Zile development is co-ordinated from the [Zile project page][]
   at [GNU Savannah][].
 * GNU maintains an [archive of past releases][releases]. This is a
   [mirror][] for faster downloads and to reduce stress on the main GNU
   machine.

 [mirror]:            http://www.gnu.org/order/ftp.html
 [releases]:          http://ftpmirror.gnu.org/zile/
 [zile]:              http://www.gnu.org/s/zile/
 [zile project page]: http://savannah.gnu.org/projects/zile/


## Mailing Lists

Questions, comments and requests should be sent to the [Zile users
list][help-zile].

See REPORTING BUGS below for the bug reporting mailing list address.

 [help-zile]: mailto:help-zile@gnu.org


# OBTAINING THE LATEST SOURCES

If you are just building GNU Zile from an [official release][releases],
you should not normally need to run `./bootstrap` or `autoreconf`; just
go ahead and start with `./configure`.

If you are trying to build GNU Zile from the [development sources][git],
`./configure` will not work until the `./bootstrap` script has completed
successfully.

 [git]: http://git.sv.gnu.org/cgit/zile.git


## Official Release

We archive compressed tarballs of all [recent GNU Zile releases][releases].

Additionally, we sometimes upload compressed tarballs of
[unstable prereleases][alpha].

Official tarballs are supplied with a [GnuPG][] detached signature file
so that you can verify that the corresponding tarball is still the same
file that was released by the owner of its GPG key ID. First, be sure to
download both the .sig file and the corresponding release:

    wget http://ftpmirror.gnu.org/zile/zile-2.3.24.tar.gz
    wget http://ftpmirror.gnu.org/zile/zile-2.3.24.tar.gz.sig

then run a command like this:

    gpg --verify zile-2.3.24.tar.gz.sig

If that command fails because you don't have the required public key,
then run this command to import it:

    gpg --keyserver keys.gnupg.net --recv-keys 80EE4A00

and then rerun the `gpg --verify' command.

Generic instructions for how to build GNU Zile from a release tarball
are contained in the file [INSTALL][].

If you are missing any of the prerequisite libraries needed to
successfully build GNU Zile, the `configure` script will abort itself
and tell you right away.

 [alpha]: http://alpha.gnu.org/gnu/zile
 [gnupg]: http://www.gnupg.org/


## Development Sources

Zile development sources are maintained at the
[GNU Savannah git server][git]. You can fetch a read-only copy with
either:

    git clone git://git.sv.gnu.org/zile.git

or using the CVS pserver protocol:

    cvs -d:pserver:anonymous@pserver.git.sv.gnu.org:/srv/git/zile.git \
        co -d zile HEAD

If you are behind a firewall that blocks the git protocol, you can force
git to transparently rewrite all savannah references to use http:

    git config --global url.http://git.sv.gnu.org/r/.insteadof \
        git://git.sv.gnu.org/

When you are building GNU Zile from a git checkout, you first need to
run the `bootstrap` script to generate various files that are shipped in
release tarballs, but not checked in to git.

Normally, you just need to run `./bootstrap`, and it will either get
everything ready so that you can then run `./configure` as would for a
release tarball, or else tell you if your machine is missing some
packages that it needs in order to do that.

  [gitbrowser]: http://git.sv.gnu.org/cgit/zile.git


# REPORTING BUGS

If this distribution doesn't work for you, before you report the
problem, please try upgrading to the latest released version first, to
see whether your issue has been fixed already. If you can, please also
check whether the latest development sources for the next release still
exhibit the problem (see OBTAINING THE LATEST SOURCES above).

Please send bug reports, feature requests and patches to the
[bug mailing list], preferably, file them directly in the relevant
tracker at [GNU Savannah][zile project page].

When you are ready to submit a report, first, please read [this][bugs].

Zile has a suite of Lisp tests in the tests directory of the source
distribution, which you can run with:

    make check

If, when you report a bug, you can create a similar test that
demonstrates it, the maintainers will be most grateful, and it will
prevent them from accidentally reintroducing the bug in a subsequent
release.

 [bugs]:      http://www.chiark.greenend.org.uk/~sgtatham/bugs.html
 [bug-zile]:  mailto:bug-zile@gnu.org
