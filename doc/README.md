# doc/ - Magyar

Ez könyvtár tartalmazza a kapcsolási és beültetési rajzokat pdf formában illetve a kártya használati utasítását, leírását magyarul, szintén pdf formában. A rev2-es lap még TH, a rev3 pedig 
már SMD alkatrészekkel van szerelve. A gyártáshoz szükséges Gerber file -ok a binaries/ folderben van.
A rev2 és a rev3 kapcsolás között 2 különbség van:
  - Az MCP6002 DIP tokozású alkatrész egy dupla opamp, míg az MCP6001 ugyanaz az opamp, csak SMD kivitelben. A kártyán csak 1 db opampra van szükség
  - A rev2 -es lapon R11 -el jelölt tompító ellenállás értéke 6k8, ami magas. Ezt 2k2 -re cseréltem a rev3 -as lapon. Úgy a vSID és a TVC hangereje kb egy szinten van

# doc/ - English

This folder contains the schematics and layout diagrams of the card and the Hungarian user guide.
Rev2 board is layed out with TH components while rev3 is an SMD board. The folder binaries/ contains the files needed for manufacture.
There are two differences (besides TH vs SMD) between the two rev boards:
  - MCP6002 is a dual opamp in DIP package used on rev2 board, while MCP6001 is the same, but single opamp on rev3
  - R11 value is should be lowered to 2k2 from 6k8 on rev2, so that the volume of the internal TVC sound and the volume of the generated SID sound should be 
    on the same level
