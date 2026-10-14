# binaries - Magyar
- Gerber*
  Gerber fájlok a rev2 és rev3 -as nyák gyártásához. A rev2 nyákon csak egy ellenállást kell lecserélni 6k8 ról 2k2 -re (R11)
- BOM* és PickAndPlace* fájlok
  BOM és PickAndPlace file -ok a rev3-smd gerberek mellé, JLCPCB gyártóhoz
- TVC-IO-v0.24.uf2
  0.24 -es firmware file, amit a mikrokontrollerre kell másolni. A részletekért lásd a használati útmutatót!
- flash-root-1.3-bin.zip
  A flash drive image, amit a mikrokontrollerre kell másolni. A részletekért lásd a használati útmutatót!
- flash-root-1.2-files.zip
  A flash drive tartalma, fájlonként
- tvc-256k++.bin
  Ez Z80 CPU által látott IO ROM, ami egyébként része az MCU firmware -ének. Ezt csak az emulátor fejlesztők kedvéért raktam ide.
- psram-test.uf2
  A PSRAM teszt program, azelőtt kell futtatni, mielőtt még az MCU modul a nyáklapra lenne forrasztva

# binaries - English
- Gerber*
  Gerber files for rev2 and rev3 PCB manufacturing. On the rev2 board you need to use a 2k2 resistor instead of 6k8 (R11)
- BOM* and PickAndPlace* fájlok
  BOM and PickAndPlace files for manufacturing rev3 smd board at JLCPCB.com
- TVC-IO-v0.24.uf2
  0.24 (latest as of now) firmware file that needs to be copied to the MCU. Doc explains how to do - in Hungarian...
- flash-root-1.3-bin.zip
  The latest image file that needs to be copied to the MCU. Doc explains how to do - in Hungarian...
- flash-root-1.2-files.zip
  Content of the flash drive, file by file
- tvc-256k++.bin
  This is the card's IO ROM seen by the Z80 CPU. This is part of the firmware (.uf2) file. This is here for the emulator developers.
- psram-test.uf2
  PSRAM test program, should be executed before the MCU module is soldered onto the PCB
