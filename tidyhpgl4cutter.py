#!/usr/bin/python

"""
Syntax: tidyhpgl4cutter <input file> <output file>
Take an HPGL file, and clean it of unwanted commands (currently filled polygon plotting and form feeds).
Then split it into chunks starting with a SP (select pen) command.  Sort these chunks into order of the pens used,
and reassemble them back into an HPGL file which now uses the pens in sequence.  Preserve preamble and postamble commands
(ie before the first SP and after the last)

Uses the Chiplotle library: http://music.columbia.edu/cmc/chiplotle/
"""


from chiplotle import *
from chiplotle.hpgl.commands import *
import sys

#plotter=instantiate_virtual_plotter((0,0), (20000,15000))

cmds=io.import_hpgl_file(sys.argv[1],['PG','FP','EP','FT','PM']) #omit form feed and filled shape commands

chunkstart=0
spchunks=[]

# search through the HPGL, making a note of the sections between each SP command
# this creates a list like [(6, 12), (13, 16), (17, 215), (216, 4631), (4632, 4830)]
# where the first value in each tuple is the index of the SP command and the second the
# last non-SP command
for cmdindex in xrange(0,len(cmds)):
	if isinstance(cmds[cmdindex],SP):
		spchunks.append((chunkstart,cmdindex-1))
		chunkstart=cmdindex
spchunks.append((chunkstart,len(cmds)-1))

firstchunk=spchunks.pop(0)  # remove the first section, because that's preliminary stuff that must remain at the start
lastchunk=spchunks.pop() # and the last one, for a similar reason
# sort the array of chunk indices by their pen number
sortedchunklist=sorted(spchunks, key=lambda chunk: cmds[chunk[0]].pen)
sortedcmds=[]
sortedcmds.extend(cmds[firstchunk[0]:firstchunk[1]+1])
for chunk in sortedchunklist:
	sortedcmds.extend(cmds[chunk[0]:chunk[1]+1])
sortedcmds.extend(cmds[lastchunk[0]:lastchunk[1]+1])

io.save_hpgl(sortedcmds,sys.argv[2])

