# tvc256k++ - Magyar
Ez a repository a TVC komputerhez készített TVC256k++ kártya firmware, demo és teszt programok és a HW gyártáshoz szükséges forrásokat tartalmazza.


## Licenc (License)

Ez a projekt a **GNU GPL v3** licenc alatt áll. 

Mivel a firmware szervesen magában foglalja és össze linkeli a Timo Kokkonen által készített, `GPL-3.0-or-later` licencű `psram.c` fájlt (a *FanPico* projektből), a teljes terjesztett végtermékre (firmware binárisra) a GPL v3 feltételei vonatkoznak. Ezért a szoftver terjesztése esetén a teljes forráskódot elérhetővé kell tenni a felhasználók számára.

### Egyedi komponensek licencelése:
* **Saját kódok:** A projektben található, saját fejlesztésű forrásfájlok egyenként **MIT licenc** alatt állnak. Ez azt jelenti, hogy ha a kódot kiemeli ebből a környezetből (a GPL-es fájl nélkül), szabadon felhasználhatja megengedő MIT feltételek szerint.
* **Külső könyvtárak:** A projekt által használt külső komponensek (`pico-pio-usb`, `tinyusb`, `fatfs`, `littlefs`, `zx7Decode` - Einar Saukas) a saját, megengedő nyílt forráskódú (MIT / BSD) licencük alatt maradnak.

## Gyártás
A kártyát bárki gyárthatja. Mire van hozzá szükség:
* 100nF kondi, TH, 90 fokos USB-A socket, 300mA polyfuse (2 raszteres), 2db 8.5mm -es (mindkét oldalán 3-3mm -es), 2x15 soros tüskesor. Persze lehet normál 2soros tüskesor is, de akkor az egyik oldalon nagyon ki fog lógni...
* Nyáklap. Mindegy, h rev2 vagy rev3. Érdemes aranyozott (ENIG), erősített élcsatlakozókkal legyártatni.
* WeAct Studio RP2350B Core modulra. Ez a kis modul tartalmaz minden áramkört, ami az MCU -t életben tartja, programozhatóvá teszi
* 8MB, 3.3V-os PSRAM (ESP PSRAM 64H)

A modul hátlapjára ráforrasztjuk a PSRAM -ot, az egyik képen látható módon ráforrasztjuk a 100nF kondit is. Ez lehet, h lehagyható, de én sosem mertem megtenni.
Leteszteljük a PSRAM elérést, ha a tesztprogram lefutása után, lustán, másodpercenként villog, akkor minden rendben van. Ha nem, akkor újraforrasztás, stb...
Ha a PSRAM rendben van, akkor lehet ráforrasztani a nyáklapra, az USB foglalattal és a polyfuse -zal együtt.

Én ezt az [USB foglatatot](https://kontel.hu/spd/139106/USB-CSATL-A-90-HUVELY) használtam. Ugyanitt vettem kondit és biztit.

Feltöltöd a modulra az .uf2 firmware -t (jelenleg a 0.24 a legfrissebb) majd a doksiban leírt módon a flash drive (.bin file) tartalmát. A kártya kész a használatra.



# tvc256k++ - English
This repository contains all the sources of the TVC256k++ card's firmware, demo and test programs and also sources for HW production.


## License

This project is licensed under the **GNU GPL v3**.

Since the compiled firmware includes and links against the `psram.c` file from the *FanPico* project (Copyright (C) 2025 Timo Kokkonen), which is licensed under `GPL-3.0-or-later`, the combined work as a whole must be distributed under the terms of the GNU GPL v3.

### Component Licenses:
* **My Custom Code:** All custom source files written for this project are individually licensed under the permissive **MIT License**. You are free to reuse them under MIT terms if decoupled from the GPL-licensed files.
* **Third-Party Libraries:** The included libraries (`pico-pio-usb`, `tinyusb`, `fatfs`, `littlefs`, `zx7Decode` by Einar Saukas) remain under their respective permissive open-source licenses (MIT / BSD).

## Manufacturing
The card can be made by anyone. You'll need:
* 100nF capacitor, TH 90 deg USB-A socket and a 300mA polyfuse (2#), 2pcs of ~8.5mm long (3-3mm on each side), 2x15 pin header. Ofc it can be a normal 2xNN pinheader, but it will be long at the back side.
* PCB. On functionality wise it doen't matter if you use rev2 or rev3 board. Worth to order ENIG surface finish and strengthen plating on edge connectors.
* WeAct Studio's RP2350B Core module. This little board contains the MCU and all its necessities.
* 8MB PSRAM, 3.3V (ESP PSRAM 64H)

First you solder the PSRAM at the back side of the module and test it with the provided test code (to be uploaded). If the test code flashes with a 1s periodicity then all good, continue with soldering the 100nF capacitor as seen on one the images. Test again!
Solder the USB-A socket, the fuze, the pinheaders then the module. You're almost done. You have to connect the module via an USB cable to your computer and upload the (as of now the latest) 0.24 firmware, then the flash drive's image (descibed in the - Hungarian - User's guide).
Now you're done, the card is ready for use in your TVC.
