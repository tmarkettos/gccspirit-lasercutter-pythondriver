diff --git a/src/drvhpgl.cpp b/src/drvhpgl.cpp
index 947a7e8..65850f7 100644
--- a/src/drvhpgl.cpp
+++ b/src/drvhpgl.cpp
@@ -163,10 +163,78 @@ constructBase,
 
 	outf << "IN;SC;PU;PU;SP1;LT;VS" << (int) HPGLScale << "\n";
 
-	penColors = new unsigned int[options->maxPenColors + 1 + 1];	// 1 offset - 0 is not used // one more for flint ;-)
-	for (unsigned int p = 0; p <= (unsigned int) options->maxPenColors + 1; p++) {
+	// receive the pen color list in an RSString, which isn't very good for such complex parsing, so
+	// convert to a C string instead
+	RSString penColorTableRSString=options->penColorTable.value;
+	const char *penColorTableCString = penColorTableRSString.value();
+	const char *pos=penColorTableCString;
+	int countPenColorList=1;
+
+	// count the number of entries in the supplied color list
+	while (pos[0]!='\0')
+	  {
+	    if (pos[0]==',')
+	      countPenColorList++;
+	    pos++;
+	  }
+
+	// size the pen color array to take the colors in the list, or more if specified on the command line
+	if (options->maxPenColors > countPenColorList)
+	  countPenColorList = options->maxPenColors;
+
+	// create a new list of pens, and zero them
+	penColors = new unsigned int[countPenColorList + 1 + 1];	// 1 offset - 0 is not used // one more for flint ;-)
+	for (unsigned int p = 0; p <= (unsigned int) countPenColorList + 1; p++) {
 		penColors[p] = 0;
 	}
+
+	/* receive a table of pen colors in 6 digit hex format RGB, for example #112233,0xabcdef,0033dd,aa0055
+	 * and pre-fill in the table of pen colors, so that if we see these colors in the image
+	 * we allocate them to the correct pens
+	 */
+	unsigned int penColorIndex=1;
+	char hexColor[7];
+	pos=penColorTableCString;
+	while (pos != NULL)
+	  {
+	    if (pos[0] == '\0')
+	      break;
+	    if (pos[0] == '#')
+	      {
+		pos++; // ignore # prefix to numbers
+		continue;
+	      }
+	    if (pos[0] == '0' && pos[1] == 'x')
+	      {
+		pos+=2; // ignore 0x prefix to numbers
+		continue;
+	      }
+	    if (pos[0] == ',')
+	      {
+		pos++;
+		penColorIndex++; // move onto the next color
+		penColors[penColorIndex] = 0xFFFFFF; // set it to white, so we can skip pens like #112233,,#334455
+		continue;
+	      }
+	    // now look at the next 6 digits (or fewer, if at the end of the string - when the isxdigit test will fail)
+	    strncpy(hexColor,pos,6);
+	    if (isxdigit(hexColor[0]) && isxdigit(hexColor[1]) && isxdigit(hexColor[2]) && isxdigit(hexColor[3]) && isxdigit(hexColor[4]) && isxdigit(hexColor[5]))
+	      { // we have a 6 digit hex string, so fill in the color table
+		penColors[penColorIndex] = strtol(hexColor,NULL,16);
+		pos+=6;
+		continue;
+	      }
+	    errf << "Pen color table " << penColorTableRSString << " not understood (position " << (pos-penColorTableCString) << ")" << endl;
+	    abort();
+	  }
+	maxPen = penColorIndex;
+
+	for (int i=0; i<countPenColorList+1; i++)
+	  printf("Color %d: #%x\n",i,penColors[i]);
+
+	// if we found more pens that we were originally told, expand the list
+	options->maxPenColors = countPenColorList;
+
 	//   float           x_offset;
 	//   float           y_offset;
 }
@@ -268,7 +336,7 @@ void drvHPGL::open_page()
 {
 	//  Start DA hpgl color addition
 	prevColor = 5555;
-	maxPen = 0;
+	//maxPen = 0;
 	//  End DA hpgl color addition
 	outf << "IN;SC;PU;PU;SP1;LT;VS" << (int) HPGLScale << "\n";
 }
@@ -352,7 +420,7 @@ void drvHPGL::show_path()
 	 *  the hpgl subroutines.  
 	 *
 	 *  The object is to generate pen switching commands when the color
-	 *  changes.  We keep a list of pen colors, which approximate the 
+	 *  changes.  We keep a list of pen colors, which contain the 
 	 *  desired rgb colors.  Choose an existing pen number when the 
 	 *  rgb color approximates that color, and add a new color to the
 	 *  list when the rgb color is distinctly new.
@@ -363,14 +431,22 @@ void drvHPGL::show_path()
 		if (options->maxPenColors > 0) {
 			const unsigned int reducedColor = 256 * (unsigned int) (currentR() * 16) +
 				16 * (unsigned int) (currentG() * 16) + (unsigned int) (currentB() * 16);
-
+			printf("maxPen = %d, reducedColor=%x\n",maxPen,reducedColor);
+			cout << "currentR = " << currentR() << endl;
+			cout << "currentG = " << currentG() << endl;
+			cout << "currentB = " << currentB() << endl;
+		     
 			if (prevColor != reducedColor) {
 				// If color changed, see if color has been used before
 				unsigned int npen = 0;
 				if (maxPen > 0) {
 					for (unsigned int j = 1; j <= maxPen; j++) {	// 0th element is never used - 0 indicates "new" color
-						if (penColors[j] == reducedColor) {
+					  printf("Pen %d, color %x, reducedColor = %x\n",j,penColors[j],reducedColor);
+					  if ( ((penColors[j] & 0xf00000)>>20 == (unsigned int) (currentR()*15)) &&
+					       ((penColors[j] & 0x00f000)>>12 == (unsigned int) (currentG()*15)) &&
+					       ((penColors[j] & 0x0000f0)>>4 == (unsigned int) (currentB()*15)) ) {
 							npen = j;
+							printf("Using existing pen %d\n",j);
 						}
 					}
 				}
@@ -381,7 +457,9 @@ void drvHPGL::show_path()
 					}
 					npen = maxPen;
 					//cout << "npen : " << npen << " maxPenColors" << maxPenColors << endl;
-					penColors[npen] = reducedColor;
+					penColors[npen] = 65536 * (unsigned int) (currentR() * 255) +
+				256 * (unsigned int) (currentG() * 255) + (unsigned int) (currentB() * 255);
+					  printf("Pen %d, color %x, reducedColor = %x\n",npen,penColors[npen],reducedColor);
 				}
 				// Select new pen
 				prevColor = reducedColor;
diff --git a/src/drvhpgl.h b/src/drvhpgl.h
index eac45ec..00592f0 100644
--- a/src/drvhpgl.h
+++ b/src/drvhpgl.h
@@ -41,6 +41,7 @@ protected:
 		Option < bool, BoolTrueExtractor > penplotter ;
 		Option < int, IntValueExtractor > maxPenColors; 
 		Option < RSString, RSStringValueExtractor> fillinstruction;
+		Option < RSString, RSStringValueExtractor> penColorTable;
 	//	Option < bool, BoolTrueExtractor > useRGBcolors ;
 		Option < bool, BoolTrueExtractor > rot90 ;
 		Option < bool, BoolTrueExtractor > rot180 ;
@@ -50,6 +51,7 @@ protected:
 		DriverOptions():
 			penplotter(true,"-pen",0, 0, "plotter is pen plotter", 0,false),
 			maxPenColors(true,"-pencolors", "number", 0, "number of pen colors available" ,0,0),
+                        penColorTable(true,"-pencolortable","string", 0, "colors of existing pens in hex, comma separated e.g. \"0x00DD00,,#3a3aea,002d83\" (gap=white)",0,(const char *) ""),
 			fillinstruction(true,"-filltype", "string", 0, "select fill type e.g. FT 1" ,0,(const char*)"FT1"),
 			rot90 (true,"-rot90" ,0, 0, "rotate hpgl by 90 degrees",0,false),
 			rot180(true,"-rot180",0, 0, "rotate hpgl by 180 degrees",0,false),
@@ -57,6 +59,7 @@ protected:
 		{
 			ADD( penplotter );
 			ADD( maxPenColors );
+			ADD( penColorTable );
 			ADD( fillinstruction );
 			ADD( rot90 );
 			ADD( rot180 );
