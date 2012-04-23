#!/bin/bash

# convert inkscape files to laser-cutter suitable HPGL, using EPS as an
# intermediate format.  Display the output in a GUI window using hp2xx

# syntax:
# inkscape2cutterhpgl.sh somefile
# will convert somefile.svg to somefile.eps to somefile.plt

# also
# inkscape2cutterhpgl.sh somefile Acrylic4mm.SGX
# will search the 

# requires pstoedit 3.60 or later, with drvhpgl.pencolors file created from:
#  echo -e "0 1.0 1.0 1.0\n1 0.0 0.0 0.0\n2 1.0 0.0 0.0\n3 0.0 1.0 0.0\n4 1.0 1.0 0.0\n5 0.0 0.0 1.0\n6 1.0 0.0 1.0\n7 0.0 1.0 1.0\n" > drvhpgl.pencolors"
# placed in pstoedit's data directory (eg /usr/share/pstoedit/)

# currently set up for two colours (pens).  Scale factor of 1.4 seems to be
# required to rescale after EPS conversion: exactly 1.4 or sqrt(2)?
# Measured to be between 1.40x and 1.41x (ie not 1.414)

DEFAULT_MATERIAL=Card2mm.SGX
PSTOEDIT=pstoedit
INKSCAPE=inkscape
HP2XX=hp2xx

STEM=$1
if [[ -z $1 ]] ; then
  echo "Syntax: inkscape2cutterhpgl.sh svgfile [material file]"
  echo "(filename provided without extension)"
  echo "material file also searched for in Laser Settings directory"
  echo "Default material: $DEFAULT_MATERIAL"
  exit
fi

if [[ ! -z "$2" ]]; then
  if [ -f "$2" ]; then
    MATERIAL_FILE=$2
  else
    MATERIAL_FILE="$( cd "$( dirname "$0" )/Laser Settings" && readlink -f $2 )"
    if [[ ! -f $MATERIAL_FILE ]]; then
      echo "Material file $MATERIAL_FILE not found (also searched Laser Settings directory)"
      exit
    fi
  fi
fi

if [ -z "$MATERIAL_FILE" ]; then
  MATERIAL_FILE="$( dirname "$0" )/Laser Settings/$DEFAULT_MATERIAL"
fi

hash $PSTOEDIT 2>&- || { echo >&2 \
  "****** ERROR ******: pstoedit version 3.6 or later is required for conversion." \
  "Download from http://www.pstoedit.net/ and build with libplot enabled"; exit 1; }


PSTOEDIT_VERSION=`$PSTOEDIT --help 2>&1 | grep -m1 version | cut -c 19-22`
PSTOEDIT_NEW_ENOUGH=$(echo $PSTOEDIT_VERSION " > 3.59" | bc)
echo $PSTOEDIT_VERSION $PSTOEDIT_NEW_ENOUGH
if [ $PSTOEDIT_NEW_ENOUGH -ne 1 ]; then
  echo "****** WARNING ******"
  echo "For correct laser power selection you need to install"
  echo "pstoedit version 3.60 or later from"
  echo "http://www.pstoedit.net/"
  echo "with libplot enabled.  (Found version $PSTOEDIT_VERSION)."
  echo "then do:"
  echo "echo -e \"0 1.0 1.0 1.0\n1 0.0 0.0 0.0\n2 1.0 0.0 0.0\n3 0.0 1.0 0.0\n4 1.0 1.0 0.0\n5 0.0 0.0 1.0\n6 1.0 0.0 1.0\n7 0.0 1.0 1.0\n\" > drvhpgl.pencolors"
  echo "and put that file in pstoedit's data directory (eg /usr/share/pstoedit/)"
  echo "Continuing anyway..."
  echo "***** END WARNING *****"
fi


hash $HP2XX 2>&- || { echo >&2 "****** WARNING ******: hp2xx is required for previewing plots - continuing anyway"; }

# libreoffice draw, load Inkscape SVG, save as EPS
# pstoedit -f "hpgl:-pencolors 2" scan+bracket-take1.eps scan+bracket-take1.libreoffice.pstoedit.plt
# hp2xx -c23456 scan+bracket-take1.libreoffice.pstoedit.plt

SCRIPT_PARENT="$( cd "$( dirname "$0" )" && pwd )"
export PYTHONPATH=$SCRIPT_PARENT/Chiplotle-0.3.0-py2.7.egg:$PYTHON_PATH
PYTHON=python


# calibrated from test runs
#XSCALE=1.41
#YSCALE=1.41
XSCALE=1.0
YSCALE=1.0
#echo $SCRIPT_PARENT
echo "Using material $MATERIAL_FILE"
#exit
$INKSCAPE --export-eps=$STEM.eps --export-area-page --export-text-to-path --without-gui $STEM.svg
# using modified pstoedit 3.50 with -pencolortable patch
#$PSTOEDIT -f "hpgl:-pencolors 7 -pencolortable \"#000000,#ff0000,#00ff00,#ffff00,#0000ff,#ff00ff,#00ffff\"" -xscale $XSCALE -yscale $YSCALE $STEM.eps $STEM.plt
# using vanilla pstoedit 3.60 - needs a drvhpgl.pencolors file in pstoedit's data directory
$PSTOEDIT -v -f "hpgl:-pencolorsfromfile" -xscale $XSCALE -yscale $YSCALE $STEM.eps $STEM.plt
$PYTHON $SCRIPT_PARENT/tidyhpgl4cutter.py $STEM.plt $STEM.clean.plt
# display a simulated plot - map hp2xx pen colours to default Spirit GX colours
# (actually we should parse the .SGX file to extract the RGB colours)
$HP2XX -c1237465 $STEM.clean.plt &
$PYTHON $SCRIPT_PARENT/hpgl2cutter.py "$MATERIAL_FILE" $STEM.clean.plt $STEM.clean.pcl
#hpgl2cutter.py "Laser Settings/Arcmm.SGX" $STEM.plt $STEM.pcl

if [ $PSTOEDIT_NEW_ENOUGH -ne 1 ]; then
  echo "REPEAT WARNING: laser power settings incorrect due to out-of-date pstoedit (see above)"
fi
