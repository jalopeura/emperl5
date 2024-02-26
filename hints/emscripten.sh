
# ##### WebPerl - http://webperl.zero-g.net #####
# 
# Copyright (c) 2018 Hauke Daempfling (haukex@zero-g.net)
# at the Leibniz Institute of Freshwater Ecology and Inland Fisheries (IGB),
# Berlin, Germany, http://www.igb-berlin.de
# 
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl 5 itself: either the GNU General Public
# License as published by the Free Software Foundation (either version 1,
# or, at your option, any later version), or the "Artistic License" which
# comes with Perl 5.
# 
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# See the licenses for details.
# 
# You should have received a copy of the licenses along with this program.
# If not, see http://perldoc.perl.org/index-licence.html

hostperl="$EMPERL_HOSTPERLDIR/miniperl"
hostgenerate="$EMPERL_HOSTPERLDIR/generate_uudmap"

osname="emscripten"
archname="wasm"
osvers="`perl -e 'print qx(emcc --version)=~/(\d+\.\d+\.\d+)/'`"

myhostname='localhost'
mydomain='.local'
cf_email='haukex@zero-g.net'
perladmin='root@localhost'

cc="emcc"
ld="emcc"

# prevent configure from overriding $ar and $nm
newlist=''
for item in $trylist; do
	case "$item" in
	ar|nm) ;;
	*) newlist="$newlist $item" ;;
	esac
done
trylist="$newlist"

nm="emnm"  # note from Glossary: 'After Configure runs, the value is reset to a plain "nm" and is not useful.'
ar="emar"  # note from Glossary: 'After Configure runs, the value is reset to a plain "ar" and is not useful.'
ranlib="emranlib"

# Here's a fun one: apparently, when building perlmini.c, emcc notices that it's a symlink to perl.c, and compiles to perl.o
# (because there is no -o option), so the final perl ends up thinking it's miniperl (shown in "perl -v", @INC doesn't work, etc.).
# Because of this and other issues I've had with symlinks, I'm switching to hard links instead.
# (Another possible fix might be to fix the Makefile steps so that they use the -o option, but this solution works for now.)
#TODO Later: In NODEFS, does Perl's -e test work correctly on symlinks? (./t/TEST was having issues detecting ./t/perl, a symlink to ./perl).
lns="/bin/ln"

prefix="$EMPERL_PREFIX"
inc_version_list="none"

man1dir="none"
man3dir="none"

sysroot="$EMSCRIPTEN/system"
loclibpth=''
glibpth=''

usemymalloc="n"
usemallocwrap="define"
usemultiplicity="define"
uselargefiles="n"
usenm='undef'
d_procselfexe='undef'

d_dlopen='undef'
dlsrc='none'

#TODO: almost all of the known_extensions are still being built. we should probably exclude some of them! (see also nonxs_ext)
# [arybase attributes B Compress/Raw/Bzip2 Compress/Raw/Zlib Cwd Data/Dumper
# Devel/Peek Devel/PPPort Digest/MD5 Digest/SHA Encode Fcntl File/DosGlob
# File/Glob Filter/Util/Call Hash/Util Hash/Util/FieldHash I18N/Langinfo IO
# List/Util Math/BigInt/FastCalc MIME/Base64 mro Opcode PerlIO/encoding
# PerlIO/mmap PerlIO/scalar PerlIO/via POSIX re SDBM_File Socket Storable
# Sys/Hostname Sys/Syslog threads threads/shared Tie/Hash/NamedCapture
# Time/HiRes Time/Piece Unicode/Collate Unicode/Normalize XS/APItest XS/Typemap]  
#TODO Later: Reinsert Storable after Socket, its Makefile seems to not work in our environment
static_ext="attributes B Cwd Data/Dumper Devel/Peek Digest/MD5 Digest/SHA Encode Fcntl File/Glob Hash/Util I18N/Langinfo IO List/Util mro Opcode PerlIO/encoding PerlIO/scalar PerlIO/via POSIX SDBM_File Socket Time/HiRes Time/Piece Unicode/Normalize WebPerl $EMPERL_STATIC_EXT"
dynamic_ext=''

# It *looks* like shm*, sem* and a few others exist in Emscripten's libc,
# but I'm not sure why Configure isn't detecting them. But at the moment I'm not going
# to worry about them, and just not build IPC-SysV.
noextensions='IPC/SysV'

d_libname_unique="define"

# For the following values, as far as I can tell by looking into Emscripten's
# libc sources, Configure *appears* to misdetect them. Either Configure is wrong,
# or I am wrong, so further investigation is needed.
d_getnameinfo='define'
#d_prctl='define' # hm, it's present in the libc source, but Configure shows Emscripten error output? -> for now, assume it's not available

# Configure seems to think the following two aren't available, although they seem to be in the Emscripten sources - leave them out anyway
#d_recvmsg='define'
#d_sendmsg='define'

d_getgrgid_r='define'
d_getgrnam_r='define'

# Emscripten does not have signals support (documentation isn't 100% clear on this? but see "$EMSCRIPTEN/system/include/libc/setjmp.h")
# but if you do: grep -r 'Calling stub instead of' "$EMSCRIPTEN"
# you'll see the unsupported stuff (as of 1.37.35):
# signal() sigaction() sigprocmask() __libc_current_sigrtmin __libc_current_sigrtmax kill() killpg() siginterrupt() raise() pause()
# plus: "Calling longjmp() instead of siglongjmp()"
d_sigaction='define'
d_sigprocmask='define'
d_killpg='define'
d_pause='define'
d_sigsetjmp='define' # this also disables Perl's use of siglongjmp() (see config.h)
# the others either aren't used by Perl (like siginterrupt) or can't be Configure'd (like kill)
#TODO Later: currently I've disabled Perl's use of signal() by patching the source - maybe there's a better way?

# Emscripten doesn't actually have these either (see "$EMSCRIPTEN/src/library.js")
d_wait4='define'
d_waitpid='define'
d_fork='define' # BUT, perl needs this one to at least build
d_vfork='define'
d_pseudofork='define'

# currently pthreads support is experimental
# http://kripken.github.io/emscripten-site/docs/porting/pthreads.html
i_pthread='undef'
d_pthread_atfork='undef'
d_pthread_attr_setscope='undef'
d_pthread_yield='undef'

# We're avoiding all the 64-bit stuff for now.
# Commented out stuff is correctly detected.
#TODO: JavaScript uses 64-bit IEEE double FP numbers - will Perl use those?
#TODO: Now that we've switched to WebAssembly, can we use 64 bits everywhere?
# see https://groups.google.com/forum/#!topic/emscripten-discuss/nWmO3gi8_Jg
#use64bitall='undef'
#use64bitint='undef'
#usemorebits='undef'
#usequadmath='undef'
#TODO Later: Why does Configure seem to ignore the following? (and do we care?)
d_quad='undef'

#TODO Later: The test for "selectminbits" seems to fail,
# the error appears to be coming from this line (because apparently stream.stream_ops is undefined):
# https://github.com/kripken/emscripten/blob/ddfc3e32f65/src/library_syscall.js#L750
# For now, just use this number from a build with an earlier version where this didn't fail:
selectminbits='32'

optimize="$EMPERL_OPTIMIZ"

# the following is needed for the "musl" libc provided by emscripten to provide all functions
ccflags="$ccflags -D_GNU_SOURCE -D_POSIX_C_SOURCE -Wno-compound-token-split-by-macro -fno-stack-protector"

# from Makefile.emcc / Makefile.micro
ccflags="$ccflags -DSTANDARD_C -DNO_MATHOMS"

ldflags="$ldflags $EMPERL_OPTIMIZ -s NO_EXIT_RUNTIME=1 -s ALLOW_MEMORY_GROWTH=1 -Wno-almost-asm"
# Note: these can be ignored: "WARNING:root:not all asm.js optimizations are possible with ALLOW_MEMORY_GROWTH, disabling those. [-Walmost-asm]"
# hence the switch to disable the warning above (we're not building for asm.js, just WebAssembly)

# we need WASM because Perl does a lot of unaligned memory access, and that is only supported by WASM, not asm.js.
ldflags="$ldflags -s WASM=1 -s BINARYEN_METHOD=native-wasm"
#TODO Later: figure out "-s BINARYEN_METHOD='native-wasm,interpret-binary'"
# when I tried it, I got this warning during compilation:
# "BINARYEN_ASYNC_COMPILATION disabled due to user options. This will reduce performance and compatibility (some browsers limit synchronous compilation), see https://github.com/kripken/emscripten/wiki/WebAssembly#codegen-effects"
# and this JS exception:
# abort("sync fetching of the wasm failed: you can preload it to Module['wasmBinary'] manually, or emcc.py will do that for you when generating HTML (but not JS)")

alignbytes='4'

# enable all checks for debugging (remember to keep in sync with build.sh!)
ccflags="$ccflags $EMPERL_CC_DEBUG_FLAGS"
ldflags="$ldflags $EMPERL_LD_DEBUG_FLAGS"
lddlflags="$lddlflags $EMPERL_LD_DEBUG_FLAGS"

# disable this warning, I don't think we need it - TODO: how to append this after -Wall?
ccflags="$ccflags -Wno-null-pointer-arithmetic"

# Configure apparently changes "-s ASSERTIONS=2 -s STACK_OVERFLOW_CHECK=2" to "-s -s" when converting ccflags to cppflags
# this is the current hack/workaround: copy cppflags from config.sh and fix it (TODO Later: better way would be to patch Configure)
cppflags='-D_GNU_SOURCE -D_POSIX_C_SOURCE -Wno-compound-token-split-by-macro -DSTANDARD_C -DNO_MATHOMS -Wno-null-pointer-arithmetic -fno-strict-aliasing -pipe -I/usr/local/include'

