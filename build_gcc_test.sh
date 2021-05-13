#!/bin/sh

# Instructions for building gcc 9.x from source.

# This gcc build script is free software; you can redistribute it and/or modify
# it under the terms of the MIT license.


#======================================================================
# User configuration
#======================================================================

# Provide the version of gcc being built (e.g. 9.1.0)

#echo $# arguments
if [ "$#" -ne 1 ];
    then echo "usage: you must input gcc version! ex. 10.2.0";
    exit;
fi
gcc_version=$1
echo "preparing to build gcc-${gcc_version}..."
# Additional makefile options.  E.g., "-j 4" for parallel builds.  Parallel
# builds are faster, however it can cause a build to fail if the project
# makefile does not support parallel build.
make_flags="-j $(nproc)"

# Architecture we are building for.
arch_flags="-march=x86-64"

# Target linux/gnu
build_target=x86_64-unknown-linux-gnu

# File locations.  Use 'install_dir' to specify where gcc will be installed.
# The other directories are used only during the build process, and can later be
# deleted.
#
# WARNING: do not make 'source_dir' and 'build_dir' the same, or
# subdirectory of each other! It will cause build problems.
install_dir=${HOME}/opt/gcc-${gcc_version}
build_dir=${HOME}/tmp/gcc-${gcc_version}_build
source_dir=${HOME}/tmp/gcc-${gcc_version}_source
tarfile_dir=${HOME}/tmp/gcc-${gcc_version}_tarballs

# String which gets embedded into gcc version info, can be accessed at
# runtime. Use to indicate who/what/when has built this compiler.
packageversion="$(whoami)-$(hostname -s)"

# gcc requires that various tools and packages be available for use in the build
# procedure, including several support libraries are necessary to build gcc. 

# We will rely on gcc builtin tool "contrib/download_prerequisites" to download
# prerequisted.


#======================================================================
# Support functions
#======================================================================


__die()
{
    echo $*
    exit 1
}


__banner()
{
    echo "============================================================"
    echo $*
    echo "============================================================"
}


__untar()
{
    dir="$1";
    file="$2"
    case $file in
        *xz)
            tar xJ -C "$dir" -f "$file"
            ;;
        *bz2)
            tar xj -C "$dir" -f "$file"
            ;;
        *gz)
            tar xz -C "$dir" -f "$file"
            ;;
        *)
            __die "don't know how to unzip $file"
            ;;
    esac
}


__abort()
{
        cat <<EOF
***************
*** ABORTED ***
***************
An error occurred. Exiting...
EOF
        exit 1
}


__wget()
{
    urlroot=$1; shift
    tarfile=$1; shift

    if [ ! -e "$tarfile_dir/$tarfile" ]; then
        wget --verbose ${urlroot}/$tarfile --directory-prefix="$tarfile_dir"
    else
        echo "already downloaded: $tarfile  '$tarfile_dir/$tarfile'"
    fi
}


# Set script to abort on any command that results an error status
trap '__abort' 0
set -e


#======================================================================
# Directory creation
#======================================================================


__banner Creating directories

# ensure workspace directories don't already exist
for d in  "$build_dir"  ; do
    if [ -d  "$d" ]; then
        __die "build directory already exists - in order for clean build, please remove and try again: $d"
    fi
done

for d in "$install_dir" "$build_dir" "$source_dir" "$tarfile_dir" ;
do
    test  -d "$d" || mkdir --verbose -p $d
done


#======================================================================
# Download source code
#======================================================================


# This step requires internet access.  If you dont have internet access, then
# obtain the tarfiles via an alternative manner, and place in the
# "$tarfile_dir"

__banner Downloading source code

gcc_tarfile=gcc-${gcc_version}.tar.gz

__wget ftp://gcc.gnu.org/pub/gcc/releases/gcc-$gcc_version  $gcc_tarfile

# Check tarfiles are found, if not found, dont proceed


#======================================================================
# Unpack source tarfiles
#======================================================================


__banner Unpacking source code

# We are using gcc's feature of in-source builds.  If each dependency is placed
# within the gcc source directory, they will automatically get built during the
# build of gcc.

__untar  "$source_dir"  "$tarfile_dir/$gcc_tarfile"

cd "$source_dir/gcc-${gcc_version}" && ./contrib/download_prerequisites

#======================================================================
# Clean environment
#======================================================================


# Before beginning the configuration and build, clean the current shell of all
# environment variables, and set only the minimum that should be required. This
# prevents all sorts of unintended interactions between environment variables
# and the build process.

__banner Cleaning environment

# store USER, HOME and then completely clear environment
U=$USER
H=$HOME

for i in $(env | awk -F"=" '{print $1}') ;
do
    unset $i || true   # ignore unset fails
done

# restore
export USER=$U
export HOME=$H
export PATH=/usr/local/bin:/usr/bin:/bin:/sbin:/usr/sbin

echo shell environment follows:
env


#======================================================================
# Configure
#======================================================================


__banner Configuring source code

cd "${build_dir}"

CC=gcc
CXX=g++
OPT_FLAGS="-O2 $gflags -Wall  $arch_flags"
CC="$CC" CXX="$CXX" CFLAGS="$OPT_FLAGS" \
    CXXFLAGS="`echo " $OPT_FLAGS " | sed 's/ -Wall / /g'`" \
    $source_dir/gcc-${gcc_version}/configure --prefix=${install_dir} \
    --enable-bootstrap \
    --enable-shared \
    --enable-threads=posix \
    --enable-checking=release \
    --with-system-zlib \
    --enable-__cxa_atexit \
    --disable-libunwind-exceptions \
    --enable-linker-build-id \
    --enable-languages=c,c++,lto \
    --disable-vtable-verify \
    --with-default-libstdcxx-abi=new \
    --enable-libstdcxx-debug  \
    --without-included-gettext  \
    --enable-plugin \
    --disable-initfini-array \
    --disable-libgcj \
    --enable-plugin  \
    --disable-multilib \
    --with-tune=generic \
    --build=${build_target} \
    --target=${build_target} \
    --host=${build_target} \
    --with-pkgversion="$packageversion"


#======================================================================
# Compiling
#======================================================================


cd "$build_dir"
make BOOT_CFLAGS="$OPT_FLAGS" $make_flags bootstrap

# If desired, run the gcc test phase by uncommenting following line

#make check


#======================================================================
# Install
#======================================================================


__banner Installing

make install


#======================================================================
# Post build
#======================================================================
echo "Your gcc-${gcc_version} has been built successfully and you can invoke it by using its\
 absolute path without interfere with your current system gcc by: $install_dir/gcc"



__banner Complete

trap : 0

#end
