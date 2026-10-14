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
* 100nF kondi, TH, 90 fokos USB socket, 300mA polyfuse, 2db 8.5mm -es (mindkét oldalán 3-3mm -es), 2x15 soros tüskesor. Persze lehet normál 2soros tüskesor is, de akkor az egyik oldalon nagyon ki fog lógni...
* Nyáklap. Mindegy, h rev2 vagy rev3. Érdemes aranyozott (ENIG), erősített élcsatlakozókkal legyártatni.
* We Act Core - RP2350B modulra. Ez a kis modul tartalmaz minden áramkört, ami az MCU -t életben tartja, programozhatóvá teszi
* 8MB, 3.3V-os PSRAM

A modul hátlapjára ráforrasztjuk a PSRAM -ot, az egyik képen látható módon ráforrasztjuk a 100nF kondit is. Ez lehet, h lehagyható, de én sosem mertem megtenni.
Leteszteljük a PSRAM elérést, ha a tesztprogram lefutása után, lustán, másodpercenként villog, akkor minden rendben van. Ha nem, akkor újraforrasztás, stb...
Ha a PSRAM rendben van, akkor lehet ráforrasztani a nyáklapra, az USB foglalattal és a polyfuse -zal együtt. Kész.
[USB socket](https://kontel.hu/spd/139106/USB-CSATL-A-90-HUVELY)


# tvc256k++ - English
This repository contains all the sources of the TVC256k++ card's firmware, demo and test programs and also sources for HW production.


## License

This project is licensed under the **GNU GPL v3**.

Since the compiled firmware includes and links against the `psram.c` file from the *FanPico* project (Copyright (C) 2025 Timo Kokkonen), which is licensed under `GPL-3.0-or-later`, the combined work as a whole must be distributed under the terms of the GNU GPL v3.

### Component Licenses:
* **My Custom Code:** All custom source files written for this project are individually licensed under the permissive **MIT License**. You are free to reuse them under MIT terms if decoupled from the GPL-licensed files.
* **Third-Party Libraries:** The included libraries (`pico-pio-usb`, `tinyusb`, `fatfs`, `littlefs`, `zx7Decode` by Einar Saukas) remain under their respective permissive open-source licenses (MIT / BSD).
