# bsnes-plus

bsnes-plus (or bsnes+) is a fork of bsnes (based on bsnes-classic) intended to
introduce some new features and improvements, mostly aimed at debugging.

This fork of bsnes+ contains my ongoing work to add support for the [XBAND Modem](https://en.wikipedia.org/wiki/XBAND).

**Loading it:** use **System → Load Special → Load XBAND Cartridge…**

  - **Base cartridge:** your XBAND BIOS ROM.
  - **Slot cartridge:** the game. In this branch the slot ROM gets loaded but is never mapped into memory, so only the XBAND BIOS actually runs. You can leave it blank.

**You need a manifest file.** The emulator can’t recognize an XBAND ROM by itself, because the line that sets the XBAND type is commented out. Without a manifest it maps the BIOS as an ordinary cartridge and nothing works. Put xband.xml next to the BIOS and give it the same base name, so XBAND.sfc pairs with XBAND.xml. The manifest is also ignored whenever an IPS/BPS patch gets auto-applied to the ROM, so don’t keep a patch with the same name in that folder.

**Network settings are hardcoded** in ```bsnes/snes/chip/xband/xband_base.cpp:```

**Server:** ```16bit.retrocomputing.network``` (line ~373)
**Port:** ```56969```
**Box identity:** ```Waj04qaASNfmaRNw``` in ```xband_send_identity()```.
