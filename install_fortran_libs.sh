#!/usr/bin/env bash
#
# Install Fortran development libraries such as netCDF4-Fortran and
# MPI on macOS and Linux.
#
# Libraries written in C such as netCDF4-C can be installed using one
# compiler and can then be used in development of projects compiled
# using another compiler by simply including .h files such as
# `#include <netcdf.h>`.
#
# Fortran uses .mod files that are used such as `use netcdf, only:
# nf90_close`. They are produced by and differ between compilers. A
# .mod file produced by one compiler cannot be used in development
# when compiling with another compiler. Fortran development libraries
# must hence exists for each Fortran compiler separately.
#
# One can install the netCDF4-Fortran and two MPI libraries in
# separate directories for different Fortran compilers with this
# script.
#
# The script assumes that the netCDF4-C library is installed and
# findable. It uses the script nc-config to get dependencies.
#
# Set parameters in section `Setup` below.
#
# Prerequisites: netCDF4-C (for netCDF4-Fortran), curl, Fortran compiler.
#
# The script was tested on Mac OS X 10.9 through macOS 15 (Mavericks to Sequoia)
# and irregularly on Ubuntu.
#
# The websites to check for the latest versions are:
#   netcdf4_fortran - https://downloads.unidata.ucar.edu/netcdf/
#   netcdf3         - https://www.unidata.ucar.edu/downloads/netcdf/netcdf-3_6_3
#   openmpi         - https://www.open-mpi.org
#   mpich           - https://www.mpich.org/downloads/
#
# Note
# - Do not untabify this script because the libtool patch will not work anymore.
#
# Note on macOS using homebrew
#   One can use homebrew to install everything except the Fortran versions. This
#   is very practical. However, homebrew upgrades also netcdf-c to newer
#   versions if you install or update a package that depends on it. Then the
#   netcdf-fortran package installed with this script will not work anymore and
#   you have to rerun the script. I still do it this way because re-installing
#   netcdf-fortran with this script is very fast.
#   To use it with homebrew:
#     install homebrew
#     brew install netcdf
#   Then use the script to install all libraries that provide Fortran interfaces
#   with all your Fortran compilers, such as netcdf4-fortran, netcdf3, openmpi,
#   mpich, giving the list of your Fortran compilers below, e.g.
#   fortran_compilers="gfortran nagfor pgfortran ifort"
#
# Authors: Matthias Cuntz with testing by Stephan Thober
# Created: Mar 2026 from install_netcdf
#
# Copyright (c) 2014-2026 Matthias Cuntz - mc (at) macu (dot) de
#
# MIT License
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# --------------------------------------------------------------------
# Info

set -e
prog=$0
pprog=$(basename ${prog})
dprog=$(dirname ${prog})
pid="$$"
sys=$(uname -s | tr A-Z a-z)
ver=$(uname -r)
kern=$(uname -r | tr A-Z a-z)
if [[ "${sys}" == "darwin" ]] ; then
    ncpu=$(sysctl -n hw.ncpu)
else
    ncpu=$(( 2 * $(grep ^processor /proc/cpuinfo | wc -l) ))
fi

# --------------------------------------------------------------------
# Help

function usage () {
    printf "${pprog} [h]\n"
    printf "\n"
    printf "Install Fortran development libraries such as netCDF4-Fortran and"
    printf " MPI on macOS and Linux.\n"
    printf "There are no command line options."
    printf " Edit the Setup section in the script instead.\n"
    printf "\n"
    printf "Options\n"
    printf "    -h    Prints this help screen.\n"
    printf "\n"
    printf "Examples\n"
    printf "    ${pprog}\n"
    printf "\n"
    printf "Copyright (c) 2014-2026 Matthias Cuntz - mc (at) macu (dot) de\n"
}
while getopts "h" Option ; do
    case ${Option} in
        h) usage; exit;;
        *) printf "Error ${pprog}: unimplemented option.\n\n" 1>&2;  usage 1>&2; exit 1;;
    esac
done

# --------------------------------------------------------------------
# Setup

# Where to install
prefix=/usr/local

# Which steps to do
# steps are: 1. download, 2. unpack, 3. configure, make, install, 4. clean-up
dodownload=1 # 1: curl sources, 0: skip
docheck=1    # 1: make check, 2: make check but do not exit on errors, 0: skip
dormtar=1    # 1: rm downloaded sources, 0: skip
dosudo=1     # 1: install in ${prefix} with sudo, 0: install as user

# What is to be installed in which version (setup list)

# Basics - everything for programming with netCDF and MPI
donetcdf4_fortran=0      # make check might stop but library works
  netcdf4_fortran=4.6.2
donetcdf3=0              # currently unavailable
  netcdf3=3.6.3
doopenmpi=0
  openmpi=4.1.7          # 4.1.7 or 5.0.9
dompich=0                # one check fails on macOS but can be ignored
  mpich=5.0.0            # 4.3.2 or 5.0.0

# Known compilers: gfortran nagfor pgfortran ifort
# fortran_compilers="gfortran"
# fortran_compilers="nagfor"
fortran_compilers="gfortran nagfor"
# fortran_compilers="/opt/pgi/osx86-64/19.4/bin/pgfortran"
# fortran_compilers="pgfortran"
# # Standard Intel
# source /opt/intel/bin/compilervars.sh intel64
# fortran_compilers="ifort"
# # Intel OneAPI
# source /opt/intel/oneapi/setvars.sh
# fortran_compilers="ifort"
# # Intel @ explor
# module load intel/2019.4-full
# fortran_compilers="ifort"

# Extra CPPFLAGS and LDFLAGS, for example for libs in non-default path such as /opt/lib
if [[ "${sys}" == "darwin" ]] ; then
    if [[ -z ${HOMEBREW_PREFIX} ]] ; then
        if [[ -d /opt/homebrew ]] ; then
            HOMEBREW_PREFIX="/opt/homebrew"
        else
            HOMEBREW_PREFIX="/usr/local"
        fi
    fi
    # add path of m4 binary for netcdf et al.
    export PATH=${PATH}:${HOMEBREW_PREFIX}/opt/m4/bin
else
    HOMEBREW_PREFIX=
fi
if [[ "${sys}" == "darwin" ]] ; then
    EXTRA_CPPFLAGS="-I${HOMEBREW_PREFIX}/include"
    EXTRA_LDFLAGS="-L${HOMEBREW_PREFIX}/lib"
    if [[ -n ${ONEAPI_ROOT} ]] ; then
        EXTRA_LDFLAGS="${EXTRA_LDFLAGS} -L${prefix}/lib -L${PPATH}/lib"
        EXTRA_CPPFLAGS="${EXTRA_CPPFLAGS} -I${PPATH}/include"
    fi
else
    EXTRA_CPPFLAGS=
    EXTRA_LDFLAGS="-Wl,-rpath=${prefix}/lib"
fi

# Path to zlib's and pthread's include/ lib/ directories (e.g. lib/libz.*)
# Path to curl lib (libcurl.*) for cdo
if [[ "${sys}" == "darwin" ]] ; then
    PPATH=/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr
else
    PPATH=/usr
    if [[ ${kern} == *microsoft ]] ; then
        CURLLIB=/usr/lib/x86_64-linux-gnu
    else
        CURLLIB=/usr/lib64
    fi
fi

# Extra flag for FTP with curl
if [[ "${sys}" == "darwin" ]] ; then
    FTPFLAG=""
else
    FTPFLAG="--disable-epsv"
fi

# PGI path
if [[ "${sys}" == "darwin" ]] ; then
    pgipath=/opt/pgi/osx86-64/17.10
fi

# CMake executable
if [[ "${sys}" == "darwin" ]] ; then
    if [[ -f /Applications/CMake.app/Contents/bin/cmake ]] ; then
        CMAKE=/Applications/CMake.app/Contents/bin/cmake
    else
        CMAKE=cmake
    fi
else
    CMAKE=cmake
fi

# --------------------------------------------------------------------
# Functions

# Helper: echo before executing command 
function echo_and_eval()
{
    echo $@
    eval $@
}

# Downloading and unpacking
function download() {
    izbase=${1}
    ihttp=${2}
    if [[ ${dodownload} -eq 1 ]] ; then curl ${FTPFLAG} -L -o ${izbase} ${ihttp}/${izbase} ; fi
}

function download_github() {
    izbase=${1}
    ihttp=${2}
    if [[ ${dodownload} -eq 1 ]] ; then curl -L -o ${izbase} ${ihttp} ; fi
}

function unpack() {
    izbase=${1}
    ibase=${2}
    case ${izbase#${ibase}} in
        *.tar)     tar -xvf  ${izbase} ;;
        *.tar.bz)  tar -xvjf ${izbase} ;;
        *.tar.bz2) tar -xvjf ${izbase} ;;
        *.tar.gz)  tar -xvzf ${izbase} ;;
        *.tar.z)   tar -xvZf ${izbase} ;;
        *.tar.Z)   tar -xvZf ${izbase} ;;
        *.tar.xz)  tar -xvJf ${izbase} ;;
        *.zip)     unzip     ${izbase} ;;
        *) printf "Error: compression not known ${izbase#${ibase}}\n\n" 1>&2; exit 1 ;;
    esac
}

function download_unpack() {
    ibase=${1}
    izbase=${2}
    ihttp=${3}
    download ${izbase} ${ihttp}
    unpack ${izbase} ${ibase}
}

function download_github_unpack() {
    ibase=${1}
    izbase=${2}
    ihttp=${3}
    download_github ${izbase} ${ihttp}
    unpack ${izbase} ${ibase}
}

# Configure, make, check, install
function configure() {
    ibase=${1}
    bconf=${2}
    aconf=${3}
    cd ${ibase}
    echo_and_eval "${bconf}" LDFLAGS=\"-L${prefix}/lib ${EXTRA_LDFLAGS}\" \
                  CPPFLAGS=\"-I${prefix}/include ${EXTRA_CPPFLAGS}\" \
                  ./configure --prefix=${iprefix} ${aconf}
}

function configure_nocpp() {
    ibase=${1}
    bconf=${2}
    aconf=${3}
    cd ${ibase}
    echo_and_eval "${bconf}" LDFLAGS=\"-L${prefix}/lib ${EXTRA_LDFLAGS}\" \
                  CPPFLAGS=\"${EXTRA_CPPFLAGS}\" \
                  ./configure --prefix=${iprefix} ${aconf}
}

function configure_make() {
    configure "$@"
    make -j ${ncpu}
}

function configure_make_nocpp() {
    configure_nocpp "$@"
    make -j ${ncpu}
}

function check() {
    case ${docheck} in
        1) make -j ${ncpu} check ;;
        2) set +e ; make -j ${ncpu} check ; set -e ;;
        *) : ;;
    esac
}

function check_test() {
    case ${docheck} in
        1) make -j ${ncpu} test ;;
        2) set +e ; make -j ${ncpu} test ; set -e ;;
        *) : ;;
    esac
}

function install() {
    mconf=${1}
    if [[ ${dosudo} -eq 1 ]] ; then
        sudo make install ${mconf}
    else
        make install ${mconf}
    fi
}

function configure_make_check_install() {
    ibase=${1}
    bconf=${2}
    aconf=${3}
    configure_make ${ibase} "${bconf}" "${aconf}"
    check
    install
}

function configure_make_nocpp_check_install() {
    ibase=${1}
    bconf=${2}
    aconf=${3}
    configure_make_nocpp ${ibase} "${bconf}" "${aconf}"
    check
    install
}

# Patch netCDF4-Fortran for NAG compiler
function apply_netcdf_fortran_nag_patch() {
    #
    printf "Patch NetCDF ${netcdf4_fortran}\n"
    # patch ${base}/m4/libtool.m4 patchit.${pid}
    sed -n -e "/nagbegin.netcdf${netcdf4_fortran}.patch/,/nagend.netcdf${netcdf4_fortran}.patch/p" \
        ${dprog}/${pprog} > patchit.${pid}
    case ${netcdf4_fortran} in # normal: diff old new > patch
        4.2) # -R because was done with: diff new old > patch
            patch -R ${base}/m4/libtool.m4 patchit.${pid}
            ;;
        4.4.1) # -R because was done with: diff new old > patch
            patch -R ${base}/m4/libtool.m4 patchit.${pid}
            ;;
        4.4.2) # patch directly libtool
            patch ${base}/libtool patchit.${pid}
            ;;
        4.4.3) # do not patch libtool but change F77 test file
            sed -i -e 's/call EXIT/stop/' ${base}/nf_test/nf_test.F
            ;;
        4.4.4) # do not patch libtool but change F77 test files
            sed -i -e 's/call EXIT/stop/'  ${base}/nf_test/nf_test.F
            sed -i -e 's/&[[:blank:]]*$//' ${base}/nf_test/ftst_path.F
            sed -i -e 's/&[[:blank:]]*$//' ${base}/nf_test/ftst_rengrps.F
            sed -i -e 's/&[[:blank:]]*$//' ${base}/nf03_test/test03_read.F
            sed -i -e 's/&[[:blank:]]*$//' ${base}/nf03_test/test03_write.F
            sed -i -e 's/&[[:blank:]]*$//' ${base}/nf03_test/util03.F
            sed -i -e 's/&[[:blank:]]*$//' ${base}/nf03_test/f03tst_open_mem.F
            sed -i -e '/#endif/i\
#else\
subroutine dummy\
end subroutine dummy\
' ${base}/fortran/nf_logging.F90
            ;;
        4.4.5) # NAG does not allow compiling empty source files
            sed -i -e 's/include/ include/' ${base}/nf_test/ftst_rengrps.F
            sed -i -e '/#endif/i\
#else\
subroutine dummy\
end subroutine dummy\
' ${base}/fortran/nf_logging.F90
            ;;
        4.5.2 | 4.5.3) # patch configure script (diff old new > patch)
            patch ${base}/configure patchit.${pid}
            ;;
        *)
            true
            ;;
    esac
    if [[ -f patchit.${pid} ]] ; then rm patchit.${pid} ; fi
}

# Cleanup install directory
function cleanup() {
    ibase=${1}
    izbase=${2}
    if [[ ${dosudo} -eq 1 ]] ; then
        sudo rm -rf ${ibase}
        if [[ ${dormtar} -eq 1 ]] ; then sudo rm ${izbase} ; fi
    else
        rm -rf ${ibase}
        if [[ ${dormtar} -eq 1 ]] ; then rm ${izbase} ; fi
    fi
}

# --------------------------------------------------------------------
# Start
# --------------------------------------------------------------------

# --------------------------------------------------------------------
# sudo

iprefix=${prefix}

# get sudo password
if [[ ${dosudo} -eq 1 ]] ; then
    printf "\nsudo password for make install into ${prefix}\n"
    # Ask for sudo password upfront
    sudo -v
    # Keep-alive: update existing `sudo` time stamp until script has finished
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    # read -rs -p "sudo password for make install into ${prefix}: " supw
    printf "\n"
fi

# --------------------------------------------------------------------
# Install

# build netcdf4-fortran
if [[ ${donetcdf4_fortran} -eq 1 ]] ; then
    printf 'Build netcdf4-fortran\n'
    base=netcdf-fortran-${netcdf4_fortran}
    zbase=${base}.tar.gz
    http=https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v${netcdf4_fortran}.tar.gz
    download_github_unpack ${base} ${zbase} ${http}
    # remove netcdf from homebrew if present
    export PATH=$(echo $PATH | tr ":" "\n" | grep -v netcdf | tr "\n" ":")
    # configure / make / check / install for all fortran compilers
    for f_comp in ${fortran_compilers} ; do
        hdf5prefix=${prefix}
        netcdfcprefix=${prefix}
        case ${f_comp} in
            *pgfortran*) # first pgfortran then gfortran in case statement
                printf "${f_comp} not supported at the moment for netcdf-fortran after change to cmake.\n"
                continue
                ;;
            *gfortran*)
	        if [[ -n ${HOMEBREW_PREFIX} ]] ; then
	            hdf5prefix=${HOMEBREW_PREFIX}
	            netcdfcprefix=${HOMEBREW_PREFIX}
	        fi
                ;;
            *)
                true
                ;;
        esac
        if [[ -n ${ONEAPI_ROOT} ]] ; then
            printf "Build ${base}-oneapi\n"
            iprefix=${prefix}/${base}-oneapi
            export LIBRARY_PATH=${LIBRARY_PATH}:/usr/local/lib:${PPATH}/lib
            export CPATH=${CPATH}:/usr/local/include:${PPATH}/include
        else
            printf "Build ${base}-$(basename ${f_comp})\n"
            iprefix=${prefix}/${base}-$(basename ${f_comp})
        fi
        cd ${base}
        mkdir build
        cd build
        case ${f_comp} in
            *nag* | *gfortran*)
                # strange variables with _T such as NCSHORT_T in ftest.f
                # they are defined in confdefs.h in C-Library
                sed -e '/ftest/d' ../nf_test/CMakeLists.txt > CMakeLists.tmp
                mv CMakeLists.tmp ../nf_test/CMakeLists.txt
                # nf_rename_var test hangs with NAG compiler
                sed -e '/nf_rename_var/s/         call/C         call/' ../nf_test/nf_test.F > nf_test.tmp
                mv nf_test.tmp ../nf_test/nf_test.F
                export LIBRARY_PATH=${LIBRARY_PATH}:/usr/local/lib:${PPATH}/lib
                export CPATH=${CPATH}:/usr/local/include:${PPATH}/include
                ;;
            *)
                true
                ;;
        esac
        # static - do not set compiler again
        nclib=${netcdfcprefix}/lib/libnetcdf.a
        # if [[ "${sys}" == "darwin" ]] ; then
        #     nclib=${netcdfcprefix}/lib/libnetcdf.dylib
        # else
        #     nclib=${netcdfcprefix}/lib/libnetcdf.so
        # fi
        ncinc=${netcdfcprefix}/include
        ncstaticlibs="-lnetcdf -lhdf5 -lhdf5_hl -lsz -lz -ldl -lm -lzstd -lbz2 -lcurl -lxml2"
        ncstaticlibs="-lnetcdf -lhdf5 -lhdf5_hl -lm -lz -lzstd -lbz2 -lsz -lcurl -lxml2"
        if [[ ! -e ${nclib} ]] ; then
            # if netcdf-c not done with this script, try pkg-config
            nclibl=$(pkg-config --libs-only-L netcdf)
            nclib=${nclibl#-L}/$(basename ${nclib})
            ncinci=$(pkg-config --cflags netcdf)
            ncinc=${ncinci#-I}
            ncstaticlibs=$(pkg-config --static --libs-only-l netcdf)
            # this gives:
            #   -lnetcdf -lhdf5_hl-shared -lhdf5-shared -lm -lz -lzstd -lbz2 -lcurl -lxml2
            # the -shared do not exists?
            ncstaticlibs="$(pkg-config --static --libs-only-l netcdf | sed 's/-shared//g')"
            # ncstaticlibs="-lnetcdf -lhdf5_hl -lhdf5 -lm -lz -lzstd -lbz2 -lcurl -lxml2"
        fi
        export LD_LIBRARY_PATH=${hdf5prefix}/lib:${netcdfcprefix}/lib:${LD_LIBRARY_PATH}
        echo LDFLAGS="-L${prefix}/lib ${EXTRA_LDFLAGS}" \
           CPPFLAGS="-I${prefix}/include ${EXTRA_CPPFLAGS}" \
           ${CMAKE} .. -DCMAKE_INSTALL_PREFIX=${iprefix} \
           -DBUILD_SHARED_LIBS=OFF -DCMAKE_Fortran_COMPILER=${f_comp} \
           -DCMAKE_C_FLAGS_RELEASE=-DNDEBUG -DCMAKE_INSTALL_LIBDIR=lib \
           -DCMAKE_BUILD_TYPE=Release -DCMAKE_FIND_FRAMEWORK=LAST \
           -DCMAKE_VERBOSE_MAKEFILE=ON -Wno-dev -DBUILD_TESTING=ON \
           -DnetCDF_LIBRARIES=${nclib} -DnetCDF_INCLUDE_DIR=${ncinc} \
           -DCMAKE_LINK_FLAGS="${ncstaticlibs}"
        LDFLAGS="-L${prefix}/lib ${EXTRA_LDFLAGS}" \
           CPPFLAGS="-I${prefix}/include ${EXTRA_CPPFLAGS}" \
           ${CMAKE} .. -DCMAKE_INSTALL_PREFIX=${iprefix} \
           -DBUILD_SHARED_LIBS=OFF -DCMAKE_Fortran_COMPILER=${f_comp} \
           -DCMAKE_C_FLAGS_RELEASE=-DNDEBUG -DCMAKE_INSTALL_LIBDIR=lib \
           -DCMAKE_BUILD_TYPE=Release -DCMAKE_FIND_FRAMEWORK=LAST \
           -DCMAKE_VERBOSE_MAKEFILE=ON -Wno-dev -DBUILD_TESTING=ON \
           -DnetCDF_LIBRARIES=${nclib} -DnetCDF_INCLUDE_DIR=${ncinc} \
           -DCMAKE_LINK_FLAGS="${ncstaticlibs}"
        case ${f_comp} in
            *nag*)
                # nagfor < v7119 cannot deal with .tbd files but needs dylib files
                if [[ "${sys}" == "darwin" ]] ; then
                    vnag=$(${f_comp} -V 2>&1 | head -1 | awk '{print $NF}')
                    if [[ ${vnag} -lt 7119 ]] ; then
                        osver=$(uname -r)
                        osver=${osver%%.*}
                        if [[ ${osver} -lt 22 ]] ; then  # macOS < 13
                            # there are still links of, for example, libz.dylib in /usr/lib/
                            for i in $(find . -name link.txt -print) ; do
                                sed -e '/.tbd/s| [^ ]*\(/usr/lib/[^ ]*\).tbd| \1.dylib|g' ${i} > link.tmp
                                mv link.tmp ${i}
                            done
                        else
                            for i in $(find . -name link.txt -print) ; do
                                sed -e '/.tbd/s| [^ ]*lib/lib\([^ ]*\).tbd| -Wl,-l\1|g' ${i} > link.tmp
                                mv link.tmp ${i}
                            done
                        fi
                    fi
                fi
                ;;
            *)
                true
                ;;
        esac
        make -j ${ncpu}
        check_test
        install
        # dynamic
        if [[ ${dosudo} -eq 1 ]] ; then
            sudo rm -r *
        else
            rm -r *
        fi
        if [[ "${sys}" == "darwin" ]] ; then
            nclib=${netcdfcprefix}/lib/libnetcdf.dylib
        else
            nclib=${netcdfcprefix}/lib/libnetcdf.so
        fi
        ncinc=${netcdfcprefix}/include
        if [[ ! -e ${nclib} ]] ; then
            # if netcdf-c not done with this script, try pkg-config
            nclibl=$(pkg-config --libs-only-L netcdf)
            nclib=${nclibl#-L}/$(basename ${nclib})
            ncinci=$(pkg-config --cflags netcdf)
            ncinc=${ncinci#-I}
        fi
        echo LDFLAGS="-L${prefix}/lib ${EXTRA_LDFLAGS}" \
           CPPFLAGS="-I${prefix}/include ${EXTRA_CPPFLAGS}" \
           ${CMAKE} .. -DCMAKE_INSTALL_PREFIX=${iprefix} \
           -DBUILD_SHARED_LIBS=ON -DCMAKE_Fortran_COMPILER=${f_comp} \
           -DCMAKE_C_FLAGS_RELEASE=-DNDEBUG -DCMAKE_INSTALL_LIBDIR=lib \
           -DCMAKE_BUILD_TYPE=Release -DCMAKE_FIND_FRAMEWORK=LAST \
           -DCMAKE_VERBOSE_MAKEFILE=ON -Wno-dev -DBUILD_TESTING=ON \
           -DnetCDF_LIBRARIES=${nclib} -DnetCDF_INCLUDE_DIR=${ncinc}
        LDFLAGS="-L${prefix}/lib ${EXTRA_LDFLAGS}" \
           CPPFLAGS="-I${prefix}/include ${EXTRA_CPPFLAGS}" \
           ${CMAKE} .. -DCMAKE_INSTALL_PREFIX=${iprefix} \
           -DBUILD_SHARED_LIBS=ON -DCMAKE_Fortran_COMPILER=${f_comp} \
           -DCMAKE_C_FLAGS_RELEASE=-DNDEBUG -DCMAKE_INSTALL_LIBDIR=lib \
           -DCMAKE_BUILD_TYPE=Release -DCMAKE_FIND_FRAMEWORK=LAST \
           -DCMAKE_VERBOSE_MAKEFILE=ON -Wno-dev -DBUILD_TESTING=ON \
           -DnetCDF_LIBRARIES=${nclib} -DnetCDF_INCLUDE_DIR=${ncinc}
        case ${f_comp} in
            *nag*)
                # nagfor < v7119 cannot deal with .tbd files but needs dylib files
                if [[ "${sys}" == "darwin" ]] ; then
                    vnag=$(${f_comp} -V 2>&1 | head -1 | awk '{print $NF}')
                    if [[ ${vnag} -lt 7119 ]] ; then
                        osver=$(uname -r)
                        osver=${osver%%.*}
                        if [[ ${osver} -lt 22 ]] ; then  # macOS < 13
                            # there are still links of, for example, libz.dylib in /usr/lib/
                            for i in $(find . -name link.txt -print) ; do
                                sed -e '/.tbd/s| [^ ]*\(/usr/lib/[^ ]*\).tbd| \1.dylib|g' ${i} > link.tmp
                                mv link.tmp ${i}
                            done
                        else
                            for i in $(find . -name link.txt -print) ; do
                                sed -e '/.tbd/s| [^ ]*lib/lib\([^ ]*\).tbd| -Wl,-l\1|g' ${i} > link.tmp
                                mv link.tmp ${i}
                            done
                        fi
                    fi
                fi
                ;;
            *)
                true
                ;;
        esac
        make -j ${ncpu}
        check_test
        install
        if [[ "${sys}" == "darwin" && ${f_comp} != *nag* ]] ; then
            # set @rpath/lib explicitly in library because LC_RPATH is not working all the time
            set +e
            ilib=$(ls ${iprefix}/lib/libnetcdff.[0-9].dylib ${iprefix}/lib/libnetcdff.[0-9][0-9].dylib 2>/dev/null)
            set -e
	    # check with: otool -l ${ilib}
            if [[ ${dosudo} -eq 1 ]] ; then
                sudo install_name_tool -id ${ilib} ${ilib}
                # sudo install_name_tool -add_rpath ${iprefix}/lib ${ilib}
            else
                install_name_tool -id ${ilib} ${ilib}
                # install_name_tool -add_rpath ${iprefix}/lib ${ilib}
            fi
        fi
        cd ..
        if [[ ${dosudo} -eq 1 ]] ; then
            sudo rm -r build
        else
            rm -r build
        fi
        iprefix=${prefix}
        cd ..
    done
    cleanup ${base} ${zbase}
fi

# build netcdf3
if [[ ${donetcdf3} -eq 1 ]] ; then
    printf 'Build netcdf3\n'
    base=netcdf-${netcdf3}
    zbase=${base}.tar.gz
    http=http://www.unidata.ucar.edu/downloads/netcdf/ftp
    download_unpack ${base} ${zbase} ${http}
    # # patch test_write.F
    # sed -i -e 's/IF (err .ne. NF_EINVAL)/IF (err .ne. 0)/' ${base}/nf_test/test_write.F
    # configure / make / check / install for all fortran compilers
    for f_comp in ${fortran_compilers} ; do
        printf "Build ${base}-$(basename ${f_comp})\n"
        iprefix=${prefix}/${base}-$(basename ${f_comp})
        ncpuold=${ncpu} # does not work with make on multiple CPUs
        ncpu=1
        case ${f_comp} in
            *pgfortran*) # first pgfortran then gfortran in case statement
                EXTRA_CPPFLAGS="${EXTRA_CPPFLAGS} -DpgiFortran"
                EXTRA_LDLFAGS="${EXTRA_LDFLAGS} -L${pgipath}/lib"
                configure_make_nocpp_check_install ${base} "FC=${f_comp} FCLAGS='-O -tp=p7-64' F77=${f_comp} FFLAGS='-O -tp=p7-64'" "--enable-shared --enable-f90"
                EXTRA_CPPFLAGS="${EXTRA_CPPFLAGS% ?*}"
                EXTRA_LDFLAGS="${EXTRA_LDFLAGS% ?*}"
                ;;
            *gfortran*) # first pgfortran then gfortran in case statement
                EXTRA_CPPFLAGS="${EXTRA_CPPFLAGS} -DgFortran"
                configure_make_check_install ${base} "FC=${f_comp}" "--enable-shared --enable-f90"
                EXTRA_CPPFLAGS="${EXTRA_CPPFLAGS% ?*}"
                ;;
            *nag*)
                EXTRA_CPPFLAGS="${EXTRA_CPPFLAGS} -DNAGf90Fortran"
                configure_make_nocpp_check_install ${base} "FC=${f_comp} F77=${f_comp} FCFLAGS='-O3 -fpp -mismatch_all -kind=byte -unsharedf95 -ieee=full' FFLAGS='-O3 -fpp -mismatch_all -kind=byte -unsharedf95 -ieee=full -fixed -dusty'" "--enable-shared --enable-f90"
                EXTRA_CPPFLAGS="${EXTRA_CPPFLAGS% ?*}"
                ;;
            *ifort*)
                if [[ "${sys}" == "darwin" ]] ; then
                    configure_make_nocpp_check_install ${base} "FC=${f_comp} F77=${f_comp} FCFLAGS='-O3 -xHost -ip -no-prec-div -mdynamic-no-pic -assume byterecl -fp-model precise -m64' FFLAGS='-O3 -xHost -ip -no-prec-div -mdynamic-no-pic -assume byterecl -fp-model precise -m64'" "--enable-shared --enable-f90"
                else
                    configure_make_check_install ${base} "FC=${f_comp} F77=${f_comp} FCFLAGS='-O3 -xHost -ip -no-prec-div -static-intel -assume byterecl -fp-model precise -m64' FFLAGS='-O3 -xHost -ip -no-prec-div -static-intel -assume byterecl -fp-model precise -m64'" "--enable-shared --enable-f90"
                fi
                ;;
            *)
                printf "${pprog}: Fortran compiler not known: ${f_comp}.\n\n"
                ncpu=${ncpuold}
                iprefix=${prefix}
                continue
                ;;
        esac
        ncpu=${ncpuold}
        iprefix=${prefix}
        # clean for next fortran compiler
        make clean
        cd ..
    done
    cleanup ${base} ${zbase}
fi

# build openmpi
if [[ ${doopenmpi} -eq 1 ]] ; then
    printf 'build openmpi\n'
    base=openmpi-${openmpi}
    zbase=${base}.tar.gz
    http=http://www.open-mpi.org/software/ompi/v${openmpi%\.*}/downloads
    download_unpack ${base} ${zbase} ${http}
    # configure / make / check / install for all fortran compilers
    for f_comp in ${fortran_compilers} ; do
        if [[ -n ${ONEAPI_ROOT} ]] ; then
            printf "Build ${base}-oneapi\n"
            iprefix=${prefix}/${base}-oneapi
            export LIBRARY_PATH=${LIBRARY_PATH}:/usr/local/lib:${PPATH}/lib
            export CPATH=${CPATH}:/usr/local/include:${PPATH}/include
        else
            printf "Build ${base}-$(basename ${f_comp})\n"
            iprefix=${prefix}/${base}-$(basename ${f_comp})
        fi
        case ${f_comp} in
            *pgfortran*) # first pgfortran then gfortran in case statement
                bconf="FC=${f_comp} F77=${f_comp} FCFLAGS='-fast -tp=p7-64' FFLAGS='-fast -tp=p7-64'"
                aconf="--with-hwloc=internal --with-libevent=internal"
                ;;
            *gfortran*) # first pgfortran then gfortran in case statement
                bconf="FC=${f_comp}"
                aconf="--with-hwloc=internal --with-libevent=internal"
                ;;
            *nag*)
                # bconf="FC=${f_comp} FCFLAGS='-O3 -fpp -mismatch_all -kind=byte -unsharedf95 -ieee=full'"
                bconf="FC=${f_comp} FCFLAGS='-O3 -fpp -mismatch_all -unsharedf95 -ieee=full'"
                aconf="--with-hwloc=internal --with-libevent=internal"
                ;;
            *ifort*)
                if [[ "${sys}" == "darwin" ]] ; then
                    bconf="FC=${f_comp} FCFLAGS='-O3 -xHost -ip -no-prec-div -mdynamic-no-pic -assume byterecl -fp-model precise -m64'"
                else
                    bconf="FC=${f_comp} FCFLAGS='-O3 -xHost -ip -no-prec-div -static-intel -assume byterecl -fp-model precise -m64'"
                fi
                aconf="--with-hwloc=internal --with-libevent=internal --enable-mpi-fortran=usempi"
                ;;
            *)
                printf "${pprog}: Fortran compiler not known: ${f_comp}.\n\n"
                continue
                ;;
        esac
        configure_make_check_install ${base} "${bconf}" "${aconf}"
        iprefix=${prefix}
        # clean for next fortran compiler
        make clean
        cd ..
    done
    cleanup ${base} ${zbase}
fi

# build mpich
if [[ ${dompich} -eq 1 ]] ; then
    printf 'build mpich\n'
    base=mpich-${mpich}
    zbase=${base}.tar.gz
    http=http://www.mpich.org/static/downloads/${mpich}
    download_unpack ${base} ${zbase} ${http}
    # configure / make / check / install for all fortran compilers
    for f_comp in ${fortran_compilers} ; do
        if [[ -n ${ONEAPI_ROOT} ]] ; then
            printf "Build ${base}-oneapi\n"
            iprefix=${prefix}/${base}-oneapi
            export LIBRARY_PATH=${LIBRARY_PATH}:/usr/local/lib:${PPATH}/lib
            export CPATH=${CPATH}:/usr/local/include:${PPATH}/include
        else
            printf "Build ${base}-$(basename ${f_comp})\n"
            iprefix=${prefix}/${base}-$(basename ${f_comp})
        fi
        aconf=" "
        case ${f_comp} in
            *pgfortran*) # first pgfortran then gfortran in case statement
                bconf="FC=${f_comp} F77=${f_comp} FCFLAGS='-fast -tp=p7-64' FFLAGS='-fast -tp=p7-64'"
                ;;
            *gfortran*) # first pgfortran then gfortran in case statement
                bconf="FC=${f_comp} FFLAGS='-fallow-argument-mismatch' FCFLAGS='-fallow-argument-mismatch'"
                ;;
            *nag*)
                # bconf="FC=${f_comp} FCFLAGS='-O3 -fpp -mismatch_all -kind=byte -unsharedf95 -ieee=full' F77=${f_comp} FFLAGS='-O3 -fpp -mismatch_all -kind=byte -ieee=full'"
                bconf="FC=${f_comp} FCFLAGS='-O3 -fpp -mismatch_all -unsharedf95 -ieee=full' F77=${f_comp} FFLAGS='-O3 -fpp -mismatch_all -ieee=full'"
                aconf="--disable-shared"
                ;;
            *ifort*)
                if [[ "${sys}" == "darwin" ]] ; then
                    bconf="FC=${f_comp} FCFLAGS='-O3 -xHost -ip -no-prec-div -mdynamic-no-pic -assume byterecl -fp-model precise -m64'"
                else
                    bconf="FC=${f_comp} FCFLAGS='-O3 -xHost -ip -no-prec-div -static-intel -assume byterecl -fp-model precise -m64'"
                fi
                ;;
            *)
                printf "${pprog}: Fortran compiler not known: ${f_comp}.\n\n"
                continue
                ;;
        esac
        # configure_make_check_install ${base} "${bconf}" "${aconf}"
	configure_make ${base} "${bconf}" "${aconf}"
	# mpich needs to install first and then check
	# because it looks for mpicc in the install directory 
	install
	check
        iprefix=${prefix}
        # clean for next fortran compiler
        make clean
        cd ..
    done
    cleanup ${base} ${zbase}
fi


# --------------------------------------------------------------------
# Finish

exit 0

# --------------------------------------------------------------------
# netCDF patches
# --------------------------------------------------------------------

# --------------------------------------------------------------------
# netcdf4.2 patch for nagfor from NAG support - attention wrong way round, use patch -R
# nagbegin.netcdf4.2.patch
4054,4058d4053
<       nagfor*)
<         _LT_TAGVAR(lt_prog_compiler_wl, $1)='-Wl,-Wl,,'
<         _LT_TAGVAR(lt_prog_compiler_pic, $1)='-PIC'
<         _LT_TAGVAR(lt_prog_compiler_static, $1)='-Bstatic'
<         ;;
4485,4488d4479
<       nagfor*) # NAG Fortran 5.3
<         _LT_TAGVAR(whole_archive_flag_spec, $1)='${wl}--whole-archive`for conv in $convenience\"\"; do test  -n \"$conv\" && new_convenience=\"$new_convenience,$conv\"; done; func_echo_all \"$new_convenience\"`,-Wl,,--no-whole-archive'
<         tmp_sharedflag='-Wl,-shared'
<           ;;
4515,4517d4505
<       nagfor*) # NAG Fortran 5.3
<         _LT_TAGVAR(archive_cmds, $1)='$CC '"$tmp_sharedflag"' $libobjs $deplibs $compiler_flags ${wl}-soname,,$soname -o $lib'
<           ;;
# nagend.netcdf4.2.patch


# --------------------------------------------------------------------
# netcdf4.4.1 patch for nagfor modified from netcdf4.2 patch - attention wrong way round, use patch -R
# nagbegin.netcdf4.4.1.patch
4485,4488d4819
<       nagfor*) # NAG Fortran
<         _LT_TAGVAR(whole_archive_flag_spec, $1)='${wl}--whole-archive`for conv in $convenience\"\"; do test  -n \"$conv\" && new_convenience=\"$new_convenience,$conv\"; done; func_echo_all \"$new_convenience\"`,-Wl,,--no-whole-archive'
<         tmp_sharedflag='-Wl,-shared'
<           ;;
4515,4517d4845
<       nagfor*) # NAG Fortran
<         _LT_TAGVAR(archive_cmds, $1)='$CC '"$tmp_sharedflag"' $libobjs $deplibs $compiler_flags ${wl}-soname,,$soname -o $lib'
<           ;;
# nagend.netcdf4.4.1.patch


# --------------------------------------------------------------------
# netcdf4.4.2 patch for nagfor
# nagbegin.netcdf4.4.2.patch
357,358c357,358
< archive_cmds="\$CC -dynamiclib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags -install_name \$rpath/\$soname \$verstring \$single_module"
< archive_expsym_cmds="sed 's|^|_|' < \$export_symbols > \$output_objdir/\$libname-symbols.expsym~\$CC -dynamiclib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags -install_name \$rpath/\$soname \$verstring \$single_module \$wl-exported_symbols_list,\$output_objdir/\$libname-symbols.expsym"
---
> archive_cmds="\$CC \${wl}-dylib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags \${wl}-install_name \${wl}\$rpath/\$soname \$verstring \$single_module"
> archive_expsym_cmds="sed 's|^|_|' < \$export_symbols > \$output_objdir/\$libname-symbols.expsym~\$CC \${wl}-dylib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags \${wl}-install_name \${wl}\$rpath/\$soname \$verstring \$single_module \$wl-exported_symbols_list,\$output_objdir/\$libname-symbols.expsym"
1066a1067
>     eval "$1=\$(echo \$$1)"
1074a1076
>     eval "$1=\$(echo \$$1)"
5045c5047
<       func_warning "remember to run '$progname --finish$future_libdirs'"
---
>       func_warning "remember to run '$progname --finish $future_libdirs'"
5050c5052
<       exec_cmd='$SHELL "$progpath" $preserve_args --finish$current_libdirs'
---
>       exec_cmd='$SHELL "$progpath" $preserve_args --finish $current_libdirs'
11702,11703c11704,11705
< archive_cmds="\$CC -dynamiclib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags -install_name \$rpath/\$soname \$verstring \$single_module"
< archive_expsym_cmds="sed 's|^|_|' < \$export_symbols > \$output_objdir/\$libname-symbols.expsym~\$CC -dynamiclib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags -install_name \$rpath/\$soname \$verstring \$single_module \$wl-exported_symbols_list,\$output_objdir/\$libname-symbols.expsym"
---
> archive_cmds="\$CC \${wl}-dylib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags \${wl}-install_name \${wl}\$rpath/\$soname \$verstring \$single_module"
> archive_expsym_cmds="sed 's|^|_|' < \$export_symbols > \$output_objdir/\$libname-symbols.expsym~\$CC \${wl}-dylib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags \${wl}-install_name \${wl}\$rpath/\$soname \$verstring \$single_module \$wl-exported_symbols_list,\$output_objdir/\$libname-symbols.expsym"
11851,11852c11853,11854
< archive_cmds="\$CC -dynamiclib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags -install_name \$rpath/\$soname \$verstring \$single_module"
< archive_expsym_cmds="sed 's|^|_|' < \$export_symbols > \$output_objdir/\$libname-symbols.expsym~\$CC -dynamiclib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags -install_name \$rpath/\$soname \$verstring \$single_module \$wl-exported_symbols_list,\$output_objdir/\$libname-symbols.expsym"
---
> archive_cmds="\$CC \${wl}-dylib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags \${wl}-install_name \${wl}\$rpath/\$soname \$verstring \$single_module"
> archive_expsym_cmds="sed 's|^|_|' < \$export_symbols > \$output_objdir/\$libname-symbols.expsym~\$CC \${wl}-dylib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags \${wl}-install_name \${wl}\$rpath/\$soname \$verstring \$single_module \$wl-exported_symbols_list,\$output_objdir/\$libname-symbols.expsym"
# nagend.netcdf4.4.2.patch


# --------------------------------------------------------------------
# netcdf4.5.2 patch for nagfor
# nagbegin.netcdf4.5.2.patch
12666c12666
<     archive_cmds="\$CC -dynamiclib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags -install_name \$rpath/\$soname \$verstring $_lt_dar_single_mod$_lt_dsymutil"
---
>     archive_cmds="\$CC \${wl}-dylib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags \${wl}-install_name \${wl}\${rpath# *}/\$soname \$verstring $_lt_dar_single_mod$_lt_dsymutil"
12668c12668
<     archive_expsym_cmds="sed 's|^|_|' < \$export_symbols > \$output_objdir/\$libname-symbols.expsym~\$CC -dynamiclib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags -install_name \$rpath/\$soname \$verstring $_lt_dar_single_mod$_lt_dar_export_syms$_lt_dsymutil"
---
>     archive_expsym_cmds="sed 's|^|_|' < \$export_symbols > \$output_objdir/\$libname-symbols.expsym~\$CC \${wl}-dylib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags \${wl}-install_name \${wl}\${rpath# *}/\$soname \$verstring $_lt_dar_single_mod$_lt_dar_export_syms$_lt_dsymutil"
16512c16512
<     archive_cmds_F77="\$CC -dynamiclib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags -install_name \$rpath/\$soname \$verstring $_lt_dar_single_mod$_lt_dsymutil"
---
>     archive_cmds_F77="\$CC \${wl}-dylib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags \${wl}-install_name \${wl}\${rpath# *}/\$soname \$verstring $_lt_dar_single_mod$_lt_dsymutil"
16514c16514
<     archive_expsym_cmds_F77="sed 's|^|_|' < \$export_symbols > \$output_objdir/\$libname-symbols.expsym~\$CC -dynamiclib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags -install_name \$rpath/\$soname \$verstring $_lt_dar_single_mod$_lt_dar_export_syms$_lt_dsymutil"
---
>     archive_expsym_cmds_F77="sed 's|^|_|' < \$export_symbols > \$output_objdir/\$libname-symbols.expsym~\$CC \${wl}-dylib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags \${wl}-install_name \${wl}\${rpath# *}/\$soname \$verstring $_lt_dar_single_mod$_lt_dar_export_syms$_lt_dsymutil"
19643c19643
<     archive_cmds_FC="\$CC -dynamiclib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags -install_name \$rpath/\$soname \$verstring $_lt_dar_single_mod$_lt_dsymutil"
---
>     archive_cmds_FC="\$CC \${wl}-dylib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags \${wl}-install_name \${wl}\${rpath# *}/\$soname \$verstring $_lt_dar_single_mod$_lt_dsymutil"
19645c19645
<     archive_expsym_cmds_FC="sed 's|^|_|' < \$export_symbols > \$output_objdir/\$libname-symbols.expsym~\$CC -dynamiclib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags -install_name \$rpath/\$soname \$verstring $_lt_dar_single_mod$_lt_dar_export_syms$_lt_dsymutil"
---
>     archive_expsym_cmds_FC="sed 's|^|_|' < \$export_symbols > \$output_objdir/\$libname-symbols.expsym~\$CC \${wl}-dylib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags \${wl}-install_name \${wl}\${rpath# *}/\$soname \$verstring $_lt_dar_single_mod$_lt_dar_export_syms$_lt_dsymutil"
# nagend.netcdf4.5.2.patch


# --------------------------------------------------------------------
# netcdf4.5.3 patch for nagfor
# nagbegin.netcdf4.5.3.patch
12765c12765
<     archive_cmds="\$CC -dynamiclib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags -install_name \$rpath/\$soname \$verstring $_lt_dar_single_mod$_lt_dsymutil"
---
>     archive_cmds="\$CC \${wl}-dylib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags \${wl}-install_name \${wl}\${rpath# *}/\$soname \$verstring $_lt_dar_single_mod$_lt_dsymutil"
12767c12767
<     archive_expsym_cmds="sed 's|^|_|' < \$export_symbols > \$output_objdir/\$libname-symbols.expsym~\$CC -dynamiclib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags -install_name \$rpath/\$soname \$verstring $_lt_dar_single_mod$_lt_dar_export_syms$_lt_dsymutil"
---
>     archive_expsym_cmds="sed 's|^|_|' < \$export_symbols > \$output_objdir/\$libname-symbols.expsym~\$CC \${wl}-dylib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags \${wl}-install_name \${wl}\${rpath# *}/\$soname \$verstring $_lt_dar_single_mod$_lt_dar_export_syms$_lt_dsymutil"
16589c16589
<     archive_cmds_F77="\$CC -dynamiclib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags -install_name \$rpath/\$soname \$verstring $_lt_dar_single_mod$_lt_dsymutil"
---
>     archive_cmds_F77="\$CC \${wl}-dylib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags \${wl}-install_name \${wl}\${rpath# *}/\$soname \$verstring $_lt_dar_single_mod$_lt_dsymutil"
16591c16591
<     archive_expsym_cmds_F77="sed 's|^|_|' < \$export_symbols > \$output_objdir/\$libname-symbols.expsym~\$CC -dynamiclib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags -install_name \$rpath/\$soname \$verstring $_lt_dar_single_mod$_lt_dar_export_syms$_lt_dsymutil"
---
>     archive_expsym_cmds_F77="sed 's|^|_|' < \$export_symbols > \$output_objdir/\$libname-symbols.expsym~\$CC \${wl}-dylib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags \${wl}-install_name \${wl}\${rpath# *}/\$soname \$verstring $_lt_dar_single_mod$_lt_dar_export_syms$_lt_dsymutil"
19698c19698
<     archive_cmds_FC="\$CC -dynamiclib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags -install_name \$rpath/\$soname \$verstring $_lt_dar_single_mod$_lt_dsymutil"
---
>     archive_cmds_FC="\$CC \${wl}-dylib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags \${wl}-install_name \${wl}\${rpath# *}/\$soname \$verstring $_lt_dar_single_mod$_lt_dsymutil"
19700c19700
<     archive_expsym_cmds_FC="sed 's|^|_|' < \$export_symbols > \$output_objdir/\$libname-symbols.expsym~\$CC -dynamiclib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags -install_name \$rpath/\$soname \$verstring $_lt_dar_single_mod$_lt_dar_export_syms$_lt_dsymutil"
---
>     archive_expsym_cmds_FC="sed 's|^|_|' < \$export_symbols > \$output_objdir/\$libname-symbols.expsym~\$CC \${wl}-dylib \$allow_undefined_flag -o \$lib \$libobjs \$deplibs \$compiler_flags \${wl}-install_name \${wl}\${rpath# *}/\$soname \$verstring $_lt_dar_single_mod$_lt_dar_export_syms$_lt_dsymutil"
# nagend.netcdf4.5.3.patch
