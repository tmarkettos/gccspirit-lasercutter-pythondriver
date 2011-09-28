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

STEM=$1

# libreoffice draw, load Inkscape SVG, save as EPS
# pstoedit -f "hpgl:-pencolors 2" scan+bracket-take1.eps scan+bracket-take1.libreoffice.pstoedit.plt
# hp2xx -c23456 scan+bracket-take1.libreoffice.pstoedit.plt

inkscape --export-eps=$STEM.eps --export-area-page --export-text-to-path --without-gui $STEM.svg
pstoedit -f "hpgl:-pencolors 7 -pencolortable \"#000000,#ff0000,#00ff00,#ffff00,#0000ff,#ff00ff,#00ffff\"" -xscale 1.414 -yscale 1.414 $STEM.eps $STEM.plt
tidyhpgl4cutter.py $STEM.plt $STEM.clean.plt
hp2xx -c1234 $STEM.clean.plt &
hpgl2cutter.py "Laser Settings/OHPfilm-stack.SGX" $STEM.clean.plt $STEM.clean.pcl
#hpgl2cutter.py "Laser Settings/Arcmm.SGX" $STEM.plt $STEM.pcl
