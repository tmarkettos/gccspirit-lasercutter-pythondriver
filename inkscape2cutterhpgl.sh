#!/bin/sh

# convert inkscape files to laser-cutter suitable HPGL, using EPS as an
# intermediate format.  Display the output in a GUI window using hp2xx

# syntax:
# inkscape2cutterhpgl.sh somefile
# will convert somefile.svg to somefile.eps to somefile.plt

# requires my patched version of pstoedit that adds -pencolortable flag

# currently set up for two colours (pens).  Scale factor of 1.4 seems to be
# required to rescale after EPS conversion: exactly 1.4 or sqrt(2)?
# Measured to be 1.40x and 1.41x

DEFAULT_MATERIAL=Card2mm.SGX

STEM=$1
if [[ -z $1 ]] ; then
  echo "Syntax: inkscape2cutterhpgl.sh svgfile [material file]"
  echo "(filename provided without extension)"
  echo "material file also searched for in Laser Settings directory"
  echo "Default material: $DEFAULT_MATERIAL"
  exit
fi

if [[ ! -z $2 ]]; then
  if [ -f $2 ]; then
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


# libreoffice draw, load Inkscape SVG, save as EPS
# pstoedit -f "hpgl:-pencolors 2" scan+bracket-take1.eps scan+bracket-take1.libreoffice.pstoedit.plt
# hp2xx -c23456 scan+bracket-take1.libreoffice.pstoedit.plt

SCRIPT_PARENT="$( cd "$( dirname "$0" )" && pwd )"

#echo $SCRIPT_PARENT
echo "Using material $MATERIAL_FILE"
#exit
inkscape --export-eps=$STEM.eps --export-area-page --export-text-to-path --without-gui $STEM.svg
pstoedit -f "hpgl:-pencolors 7 -pencolortable \"#000000,#ff0000,#00ff00,#ffff00,#0000ff,#ff00ff,#00ffff\"" -xscale 1.414 -yscale 1.414 $STEM.eps $STEM.plt
$SCRIPT_PARENT/tidyhpgl4cutter.py $STEM.plt $STEM.clean.plt
hp2xx -c1234 $STEM.clean.plt &
$SCRIPT_PARENT/hpgl2cutter.py "$MATERIAL_FILE" $STEM.clean.plt $STEM.clean.pcl
#hpgl2cutter.py "Laser Settings/Arcmm.SGX" $STEM.plt $STEM.pcl
