# install_netcdf
Install open source packages to work with netCDF and openMPI on Mac OS X and Linux.

The script was initially written to install netCDF4 (hence its name) and all its
dependencies to be used with different Fortran compilers, as well as
some netCDF tools such as cdo, nco and ncview.

It is also used to install missing packages locally on computing
clusters. For example, a cluster might have the netCDF C-library
installed but not the Fortran version.

Set parameters in Setup section, as well as directories to packages that are already installed.

Prerequisites: curl, c and c++ compilers, pkg-config for nco.  
Optional prerequisites: fortran compiler (e.g. gfortran) for netcdf3 and netcdf4-fortran  
                       java compiler for antlr2, i.e. ncap2 of nco

The script was tested on Mac OS X 10.9 through 10.11 (Mavericks, Yosemite, El Capitan).  
It was not tested on Ubuntu for quite a while.

#### Dependencies are:

| | |
| --- | --- |
| hdf5 | <- zlib, szip |
| netcdf4 | <- hdf5 |
| netcdf4\_fortran | <- netcdf4 |
| grib\_api | <- netcdf4, jasper, libpng |
|    or | |
| eccodes | <- netcdf4, jasper, libpng |
| cdo | <- netcdf4, proj4, grib_api or eccodes, udunits |
| nco | <- netcdf4, gsl, udunits, pkg-config, antlr v2 (not v3/4) for ncap2 |
| ncview | <- netcdf4, udunits |
| tiff | <- jpeg |
| ffmpeg | <- yasm |

#### The websites to check for the latest versions are:

| | |
| --- | --- |
| zlib | http://zlib.net |
| openssl | https://www.openssl.org/source/ |
| szip | http://www.hdfgroup.org/ftp/lib-external/szip/ |
| hdf5 | http://www.hdfgroup.org/ftp/HDF5/releases/ |
| netcdf4/\_fortran | https://www.unidata.ucar.edu/downloads/netcdf |
| netcdf3 | http://www.unidata.ucar.edu/downloads/netcdf/netcdf-3\_6\_3 |
| udunits | ftp://ftp.unidata.ucar.edu/pub/udunits/ |
| libpng | http://sourceforge.net/projects/libpng/files/ |
| libjpeg | http://www.ijg.org/files/ |
| tiff | https://download.osgeo.org/libtiff/ |
| proj4 | https://download.osgeo.org/proj/ |
| jasper | http://www.ece.uvic.ca/~frodo/jasper/ |
| grib\_api | https://software.ecmwf.int/wiki/display/GRIB/Releases |
| eccodes | https://software.ecmwf.int/wiki/display/ECC/Releases |
| cdo | https://code.zmaw.de/projects/cdo/files |
| ncview | ftp://cirrus.ucsd.edu/pub/ncview/ |
| gsl | ftp://ftp.gnu.org/gnu/gsl/ |
| antlr | http://www.antlr2.org/download.html |
| nco | http://nco.sourceforge.net/src/ |
| openmpi | http://www.open-mpi.org |
| mpich | http://www.mpich.org/downloads/ |
| geos | https://download.osgeo.org/geos |
| gdal | https://trac.osgeo.org/gdal/wiki/DownloadSource |
| yasm | http://yasm.tortall.net/Download.html |
| ffmpeg | http://ffmpeg.org/releases/ |
| p7zip | http://sourceforge.net/projects/p7zip/ |
| hdf4 | http://www.hdfgroup.org/release4/obtain.html |
| enscript | http://ftp.gnu.org/gnu/enscript |
| htop | http://hisham.hm/htop/ |

#### Check for all latest versions by copying the following to open/xdg-open:

http://zlib.net https://www.openssl.org/source/ http://www.hdfgroup.org/ftp/lib-external/szip/ http://www.hdfgroup.org/ftp/HDF5/releases/ https://www.unidata.ucar.edu/downloads/netcdf http://www.unidata.ucar.edu/downloads/netcdf/netcdf-3\_6\_3 ftp://ftp.unidata.ucar.edu/pub/udunits/ http://sourceforge.net/projects/libpng/files/ http://www.ijg.org/files/ https://download.osgeo.org/libtiff/ https://download.osgeo.org/proj/ http://www.ece.uvic.ca/~frodo/jasper/ https://software.ecmwf.int/wiki/display/GRIB/Releases https://software.ecmwf.int/wiki/display/ECC/Releases https://code.zmaw.de/projects/cdo/files ftp://cirrus.ucsd.edu/pub/ncview/ ftp://ftp.gnu.org/gnu/gsl/ http://www.antlr2.org/download.html http://nco.sourceforge.net/src/ http://www.open-mpi.org http://www.mpich.org/downloads/ https://download.osgeo.org/geos https://trac.osgeo.org/gdal/wiki/DownloadSource http://yasm.tortall.net/Download.html http://ffmpeg.org/releases/ http://sourceforge.net/projects/p7zip/ http://www.hdfgroup.org/release4/obtain.html http://ftp.gnu.org/gnu/enscript http://hisham.hm/htop/releases/

#### Note

- Do not untabify the script because the netcdf_fortran libtool patch will not work anymore.
- If some libraries are already installed such as png, set dolibpng=0 below.
- One can set EXTRA_CPPFLAGS and EXTRA_LDFLAGS if the compilers do not find it automatically, for example:  
EXTRA_LDFLAGS='-L/opt/local'

#### Note on Mac OS X using homebrew

install homebrew with

    /usr/bin/ruby -e "$(curl -fsSL  https://raw.githubusercontent.com/Homebrew/install/master/install)"  

install the following packages via homebrew by typing: brew install <PACKAGE>

    brew install gcc netcdf cmake udunits proj jasper gsl
    brew cask install java
    brew install antlr@2 geos gdal ffmpeg enscript htop
    brew install nco
    brew install ncview

 Set CMAKE below to cmake.  
 All libraries should link into /usr/local. If a package cannot link properly then try
 
    brew link <PACKAGE>
 
 This normally shows a directory which cannot be written. Set owner to username, e.g.
 
    sudo chown ${USER} /usr/local/share/man/man3
 
 Then, do not select the instaled packages below
 
    dozlib=0
    doszip=0
    dohdf5=0
    donetcdf4=0
    doudunits=0
    dolibpng=0
    dolibjpeg=0
    dotiff=0
    doproj4=0
    dojasper=0
    dogsl=0
    doantlr=0
	donco=0
	doncview=0

 Then use the script to install all libraries that provide Fortran interfaces with all your Fortran compilers,
 such as netcdf4-fortran, netcdf3, openmpi, mpich, giving the list of your Fortran compilers below, e.g.
 
    fortran_compilers="gfortran nagfor pgfortran ifort"
 
 Also install cdo with the script because of the dropped science support of homebrew.  
 Homebrew can also be used exclusivley for the additional packages:
 
    geos
    gdal
    ffmpeg
    enscript
    htop

#### Note on (Scientific) Linux

 zlib installed by default.  
 Install antlr-C++ bindings from paket manager.

#### Note on Ubuntu

 install the following software from package management via the command line
 by typing sudo apt install <PACKAGE>
 
    zlib [installed by default on Ubuntu]
    or
    libz-mingw-w64 [on Ubuntu on Windows]
    libpng-dev
    libtiff-dev [installs libjpeg-dev]
    libantlr-dev
    libexpat-dev
    libcurl4-openssl-dev
    xorg-dev
    cmake
    bison
   
Therefore do not select the packages below
   
    dozlib=0
    dolibpng=0
    dolibjpeg=0
    dotiff=0
    doantlr=0

Authors: Matthias Cuntz, Stephan Thober  
Created: Oct 2014

**Copyright (c) 2014-2019 Matthias Cuntz - mc (at) macu (dot) de**
