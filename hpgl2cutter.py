#!/usr/bin/python

'''Convert HPGL to PCL suitable for sending direct to the GCC Spirit GX
laser cutter.

The laser cutter takes a modified form of PCL.  PCL itself is used for
configuring the laser cutter and sending raster images, while HPGL (a subset
of the PCL5 standard) is used for conveying vector images.  This script
attaches a suitable wrapper to be able to cut from arbitrary HPGL files. 
The full cutter command set hasn't yet been reverse engineered: see 
http://www.wiki.cl.cam.ac.uk/clwiki/CompArch/HardwareLab/LaserCutter
for limitations.  For laser cutter settings it uses SGX settings files saved
out by the Windows driver (easily editable text):

Syntax: hpgl2cutter.py settings.sgx input.hpgl output.pcl'''


import ConfigParser
import os
import sys

esc = '\x1b'

def PCLReturnToPJL(file):
  file.write(esc + '%-12345X')
  
def PCLReset(file):
  file.write(esc + 'E')
  
def PCLSmartACT(file,smartact):
  file.write(esc + "!r%sA" % (smartact and '1' or '0'))

def PCLRotaryFixture(file,diameter):
  file.write(esc + "!s%dR" % diameter)

def PCLFilename(file,filename):
  file.write(esc + '!m%dN%s' % (len(filename), filename))

def PCLLaserPowerTable(file, pen):
# need to work out what R and I lines are

# R line goes here: no idea what it does yet
  file.write(esc + '!v16R')
  for colour in range(1,17):
    file.write('1')

# pen ppi (at a guess)
  file.write(esc + '!v64I')
  for colour in range(1,17):
    file.write('%04.0f' % float(pen["pen%sppi" % colour]))
# pen speed
  file.write(esc + '!v64V')
  for colour in range(1,17):
    file.write('%04.0f' % float(pen["pen%sspeed" % colour]))
#    print "PEN"+pen["pen%sspeed" % colour]
  file.write(esc + '!v64P')
  for colour in range(1,17):
    file.write('%04.0f' % (float(pen["pen%spower" % colour])*10))
  file.write(esc + '!v16D')
  for colour in range(1,17):
    flags = 0
    if (pen["pen%sautofocus" % colour] == '1'):
      flags = flags | 1
# work out difference between blowr and blowv
    if (pen["pen%sblowr" % colour] == '1'):
      flags = flags | 2
    file.write('%c' % flags)

def PCLRasterResolution(file,dpi):
  file.write(esc + '*t%sR' % dpi)

def PCLUnitOfMeasure(file,dpi):
  file.write(esc + '&u%sR' % dpi)

def PCLEnterPCLMode(file):
  file.write(esc + '%1A')
  
def PCLEnterHPGLMode(file):
  file.write(esc + '%1B')

# don't really know what this does, just guessing
# note this is heavily fixed to use +ve relative coords on E and F and X and Y
def PCLBoundingBox(file,a,b,c,d,e,f):
  file.write((esc + '*p%dA' + esc + '*p%dB' + esc + '*p%dC'+ esc + '*p%dD' + esc + '*p%dE'+ esc + '*p%dF') % (a,b,c,d,e,f))
def PCLCursorPosition(file,x,y):
  file.write((esc + '*p%+dX' + esc + '*p%+dY') % (x,y))


def ConfigSectionMap(section):
    dict1 = {}
    options = Config.options(section)
    for option in options:
        try:
            dict1[option] = Config.get(section, option)
            if dict1[option] == -1:
                DebugPrint("skip: %s" % option)
        except:
            print("exception on %s!" % option)
            dict1[option] = None
    return dict1                                                                                                



# open the config file and parse it
if (len(sys.argv) < 3):
  raise Exception('Syntax: hpgl2cutter.py settings.sgx input.hpgl output.pcl')
  
Config = ConfigParser.SafeConfigParser()
Config.read(sys.argv[1])

# for each section create a dictionary of {'element':'value'} keys, then
# put that inside a dictionary of the sections, ie
# { 'section1':{{'element1':value1},{'element2':value2}}}
print Config.sections()
sectionmap=[]
sectionlist=[]
for section in Config.sections():
  sectionmap.append(ConfigSectionMap(section))
  sectionlist.append(section)
d=dict(zip(sectionlist,sectionmap))

input=open(sys.argv[2],"rb")
output=open(sys.argv[3],"wb")

PCLReturnToPJL(output)
PCLReset(output)
# don't know which config bit is SmartACT
#PCLSmartACT(output,)
if d["PAPER"]["rotary"] == '1':
  PCLRotaryFixture(output,d["PAPER"]["ro_diam"])
PCLFilename(output,os.path.basename(sys.argv[2]))
PCLLaserPowerTable(output,d["PEN"])
PCLRasterResolution(output,508)
PCLUnitOfMeasure(output,508)
output.write(esc + '!r0N') #unknown
PCLEnterPCLMode(output)
output.write(esc + '!r1000I' + esc + '!r1000K' + esc + '!r500P') #unknown
PCLRasterResolution(output,508)
PCLUnitOfMeasure(output,508)
# don't really know what these do
#PCLBoundingBox(output,801,301,-800,-300,800,300)
#PCLBoundingBox(output,6000,6000,12000,12000,6500,6500)
#PCLCursorPosition(output,6500,6500)  # on 40x15mm, F=0 and 99990 are OK but +0 out of bbox
output.write(esc + '!m0S' + esc + '!s1S' ) #unknown
# don't bother starting and stopping raster graphics

PCLEnterHPGLMode(output)
#output.write(";PR;SP2;PD-2,-12;PD-2,-10;PD-6,-12;PU;")
#output.write(';PR;SP1;PD-1600,0;PD0,600;PD1600,0;PD0,-600;PU;ZS0;RS0;')
output.write(input.read())
PCLEnterPCLMode(output)
PCLReset(output)
PCLReturnToPJL(output)

input.close()
output.close()
