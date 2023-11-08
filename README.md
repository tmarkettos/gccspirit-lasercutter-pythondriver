# Alternative software for GCC Spirit laser cutter 

This is an alternative to the Windows driver for a GCC Spirit GX laser
cutter (purchased 2011), although it is quite possible other laser cutters
may also work.  In this repository are scripts which take input EPS and
generate output files which can be sent directly to the laser cutter via
parallel or USB.

Based on the reverse engineering below, this repository contains scripts which will:

 * Take Inkscape EPS and convert it to sane-ish HPGL (using pstoedit with 'hpgl' driver, see note below about patched version)
 * Take any HPGL and apply a PCL wrapper using a laser settings file (eg Card2mm.sgx)

The output PCL can then be dumped directly to the laser cutter (`copy file.pcl LPT3:`)

HPGL output has successfully been generated from:
 * Inkscape (via EPS)
 * Eagle (via HPGL CAM processor - see `eagle2lasercutter*.cam` jobs in the above directory)
 * QCAD (via CAM Expert)
 * OpenSCAD (via 2D projection to DXF and CAM Expert)

Syntax:
 ` inkscape2cutterhpgl.sh <svg stem> [<laser settings file.sgx>] `

This takes the filename of an SVG file (without the .svg), and optionally the name of a laser settings file (eg RichTea.SGX).  The settings file is searched for in the current directory and in the Laser Settings directory where the scripts are installed.  If no settings file is specified, Card2mm.SGX is used.

It generates a file of the same stem but .clean.pcl which can be copied directly to the laser cutter.

The script performs:
  * Conversion of SVG to EPS using Inkscape, converting text to paths.
  * Conversion of EPS to HPGL using modified pstoedit (see below), using the pen colours as defined in the default laser settings file (ie it won't currently notice if you've redefined the pen colours)
  * Tidying of the HPGL, including removing polygon fill (which the laser cutter can render, but as rasters very very slowly) and sorting by pen (so that all pen 1 cuts are made before pen 2 cuts, etc) using a python script and the chiplotle library
  * Wrapping of HPGL with the laser cutter preamble based on the laser settings file (another python script)
  * Display a rendering of the HPGL in a window using hp2xx

Caveats:
 * Relative positioning isn't yet supported.  All HPGL is plotted relative to the HPGL origin which is the bottom left: that means the card, plastic, etc will cut at the bottom left corner of the laser cutter.  The origin (HPGL 0,0) is at about -50mm,613mm: 613 is off the bottom of the honeycomb.  It will cut at 613, but burns off the metal paint off the frame.  To ensure sensible positioning, set the HPGL plot size to 850x600mm in the graphics program.
 * The Cairo graphics library 1.10 and earlier (used by Inkscape for EPS output) set the bounding box to the edges of the drawing, irrespective of the page size.  To get the page size in the cutter correct, you need to make a box (eg filled white) that is the same size as the page.  This has been fixed in Cairo 1.11 but this is currently not shipped by major distros.
 * atm26 has produced a patch (in the git repository) to pstoedit that allows supplying a table of pen:colour mappings, as an option: `-f "hpgl:-pencolortable #000000,#ff0000,#00ff00"` (pens in order starting from 1, colours in 24 bit hex).
 
## Reverse engineering

The raw data output by the driver appears to be HPGL-2 embedded in a PCL wrapper (PCL 5 allows for this: [PCL quick reference 1](http://www.virtualizationadmin.com/files/whitepapers/ultimate_printer_manual/ccPCLfrm.htm),[QR2](http://pcl.to/reference/), [QR3](http://www.sxlist.com/techref/language/pcl/decoded.htm)).  Plotter files are directly printable on a normal PCL printer (tested on HP Laserjet 4), though with some ASCII output for unknown commands.  Some codes not defined in PCL appear to be used for laser settings.  A typical file:
(`<ESC>` = ASCII 27, `^@` = ASCII 0, `^B` = ASCII 2)

 * ` <ESC> %-12345X ` exit current language and return to PJL
 * ` <ESC> E ` reset
 * (only in rotary fixture mode) ` <ESC> !s50000R ` enable rotary fixture: diameter=50.000mm
 * ` <ESC> !r1A ` '0'=no [SmartACT](http://www.gccworld.com/laserproi_en/engr_patent_main.php?ID=English_041220024039), '1'=SmartACT on
 * ` <ESC> !m18Nde3-lcd-outline.ai ` job title 'de3-lcd-outline.ai' (18 characters long)
 * ` <ESC> !v16R1111111111111111 <ESC> !v64I
0400040004000400040004000400040004000400040004000400040004000400 <ESC> !v64V10000070
10000300007005000500050005000500050005000500050005000500 <ESC> !v64P0500100005001000
100005000500050005000500050005000500050005000500 <ESC> !v16D^B^B^B^@^@^@^@^@^@^@^@^@
^@^@^@^@ ` the table of laser powers/speeds (defines 16 pens for plotting).  V line gives speed in units of 0.1%, 4 digits per pen (ie 1000 = first pen 100%, 0070 = second pen 7%, etc).  P line gives laser power in same units (0500 = 50%).  D line = flags: bit 0 autofocus, bit 1 air (raster and vector settings are interpreted by the driver)
 * ` <ESC> *t508R ` Raster graphics resolution: 508dpi
 * ` <ESC> &u508D ` Unit of measure: 508dpi (so one local unit is 1/508 inch = 0.05mm)
 * ` <ESC> !r0N ` unknown
 * ` <ESC> %1A ` Enter PCL mode
 * ` <ESC> !r70I <ESC> !r70K <ESC> !r1000P ` Laser settings in raster mode: speed 7.0%, laser power 100.0%
 * ` <ESC> *t508R ` Raster graphics resolution: 508dpi
 * ` <ESC> &u508D ` Unit of measure: 508dpi
 * ` <ESC> *p7601A <ESC> *p3001B <ESC> *p-353C <ESC> *p-2677D `
 * ` <ESC> *p+441E <ESC> *p+2771F `
   Examples: position home=1075E,100F,1075X,100Y; position relative +75E,+100F,+75X,+100Y; position relative use start point 123x456mm 3460E,9120F,3460X,9120Y; position center -7450E,-1502F,-7450X,-1502Y
 * ` <ESC> *p+441X <ESC> *p+2771Y ` position cursor to X=+441, Y=+2771 (in units of unit of measure, 0.05mm above).  +nnn and -nnn are relative moves, nnn is an absolute move
 * ` <ESC> !m0S <ESC> !s1S ` unknown
 * ` <ESC> *r1A ` start raster graphics at current cursor
 * ` <ESC> *rC ` end raster graphics
 * ` <ESC> %1B ` enable HPGL mode, using current PCL cursor position for HP-GL/2 pen position
 * ` ;PR;SP2;PD-2,-12;PD-2,-10;PD-6,-12;PD-8,-
8;PD-8,-8;PD-10,-6;PD-12,-2;PD-12,-2;PD-12,2;PD-10,2;PD-10,6... ` drawing commands: SP=select pen (laser mode), PD=draw line (pen down), PU=move (pen up), PR=plot relative
 * ` ...PD0,6000;PU;ZS0;RS0; ` end of drawing commands (ZS and RS aren't defined in HPGL)
 * ` <ESC> %1A ` leave HPGL mode (transferring HPGL pen position to PCL cursor position)
 * ` <ESC> *p-88X <ESC> *p-94Y ` final cursor positioning?  Omitted when doing positioning 'without home'
 * ` <ESC> *r1A <ESC> *rC ` start raster graphics/end raster graphics
 * ` <ESC> E <ESC> %-12345X ` reset, exit current language and return to PJL

[HP HPGL reference](http://www.hpmuseum.net/document.php?catfile=213), [other laser plotter HPGL manual](http://www.plotter-service.at/files/Hpgl_Man.pdf).  [InkCut](http://inkcut.sourceforge.net/) may be compatible, though it only outputs pure HPGL so might need a PCL wrapper adding to the output (it also can't cope with raster data though the laser cutter can).  See also [Inkscape HPGL](http://www.3x6.nl/inkscape_hpgl/Linux%20inkscape%20save%20as%20HPGL%20file%20for%20pen%20cutting%20plotter%20extension.html)  and [HPGL distiller](http://pldaniels.com/hpgl-distiller/).  [libplot](http://www.gnu.org/software/plotutils/) may be a suitable HPGL converter.  [cups-fab](https://launchpad.net/cups-fab/) ([code](http://mtm.cba.mit.edu/cups/cups_fab/), [git](http://as220.org/git/cups_fab.git/)): CUPS backend for fabrication hardware, does HPGL.

### Coordinate systems
Note in the above:
 * ` <ESC> *t508R ` Raster graphics resolution: 508dpi
 * ` <ESC> &u508D ` Unit of measure: 508dpi

Setting the unit of measure to 508dpi means that each PCL unit is 25.4/508=0.05mm.  `<ESC> *p`nnnn{A} to {F} are therefore measured in units of 0.05mm.  HPGL's native unit is 0.025mm and I think this is retained (ie a PCL unit is 2 HPGL units).  Plotting a 40x15mm box at the top left of a 200x100mm page gives:

(preamble) `<ESC>*t508R <ESC>&u508D <ESC>!r0N <ESC>%1A <ESC>!r1000I <ESC>!r1000K <ESC>!r500P <ESC>*t508R <ESC>&u508D <ESC>*p801A <ESC>*p301B <ESC>*p-800C <ESC>*p-300D <ESC>*p+800E <ESC>*p+300F <ESC>*p+800X <ESC>*p+300Y <ESC>!m0S <ESC>!s1S <ESC>*r1A <ESC>*rC <ESC>%1B;PR;SP1;PD-1600,0;PD0,600;PD1600,0;PD0,-600;PU;ZS0;RS0; <ESC>%1A <ESC>*p-800X <ESC>*p-300Y <ESC>*r1A <ESC>*rC <ESC>E <ESC>%-12345X`

Think this means A,B=top corner of bounding box, C,D=opposite corner of bounding box, E,F=home position (but not coordinate origin), X,Y=initial cursor position.  Coordinates can be either absolute (123) or relative (+123,-123).  Start at 1600,600 (in HPGL units), draw -1600,0 (left 1600=40mm), draw 0,600 (down 600=15mm), draw 1600,0 (right 40mm), draw 0,-600 (up 15mm).  So bounding box is (801,301)to(-800,-300) in 0.05mm steps = 80.05x30.05mm?  Not sure that makes sense.

Maybe <ESC>*p[A-F,X,Y] are only relevant for the PCL coordinate system.  HPGL's IP and SC commands do appear to scale the HPGL output as necessary.

Relative and center modes use entirely relative coordinates, so the cutter will start off from wherever the head is located using relative coordinates unless an absolute coordinate is found.
