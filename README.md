# install_netcdf
Install open source packages to work with netCDF and MPI on Mac OS
X and Linux.

The script `install_netcdf` was initially written to install netCDF4
(hence its name) and all its dependencies to be used with different
Fortran compilers, and to install some netCDF tools such as cdo, nco,
and ncview. It was also used to install missing packages on compute
clusters locally. For example, a cluster might have the netCDF
C-library installed but not the Fortran version.

Homebrew delivers practically all of these packages now on macOS, and
conda is used on compute clusters also delivering that also
practically all packages.

The exceptions are Fortran development libraries. Libraries written in
C such as netCDF4-C can be installed using one compiler and can then
be used in development of projects compiled using another compiler by
simply including .h files such as `#include <netcdf.h>`.

Fortran uses .mod files that are used such as `use netcdf, only:
nf90_close`. They are produced by and differ between compilers. A .mod
file produced by one compiler cannot be used in development when
compiling with another compiler. Fortran development libraries must
hence exists for each Fortran compiler separately.

Hence the script `install_netcdf` is not maintained much lately but
the installations of Fortran libraries were extracted to the script
`install_fortran_libs.sh`. It basically helps installing
netCDF4-Fortran and different MPI implementations with different
Fortran compilers in separate directories.

The only prerequisites are that netCDF4-C is installed for
netCDF4-Fortran and the utility curl.

Set parameters in the section `Setup` of the script.

Set parameters in Setup section, as well as directories to packages
that are already installed.

The script was tested on Mac OS X 10.9 through macOS 15 (Mavericks to
Sequoia) and irregularly on Ubuntu.

Authors: Matthias Cuntz, Stephan Thober  
Created: Oct 2014

**Copyright (c) 2014-2026 Matthias Cuntz - mc (at) macu (dot) de**
