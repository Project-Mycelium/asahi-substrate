# Serial Debug Access for Apple Silicon

**Purpose:** Low-level kernel debugging, boot troubleshooting, black screen investigation

---

## Overview

Apple Silicon Macs expose a debug serial port via USB-C using vendor-specific USB-PD VDM (Vendor Defined Messages). This enables kernel-level debugging even when the display is non-functional.

## Hardware Requirements

### DFU Port Locations
| Device | DFU Port |
|--------|----------|
| MacBook Air / 13" MBP | Rear left port |
| 14"/16" MacBook Pro | MagSafe-adjacent port |
| Mac Mini | Nearest to power plug |

### Cable Requirements
- **Must be USB 3.0 SuperSpeed** (not USB 2.0 charging cables)
- Cable should have ~15 internal wires
- USB 2.0-only cables lack the SBU1/SBU2 pins needed for serial

## Method 1: Two Apple Silicon Macs (Easiest)

### Setup
1. Connect two M1+ Macs via USB-C SuperSpeed cable
2. On the **host** Mac (running macOS), build macvdmtool:
   ```bash
   git clone https://github.com/AsahiLinux/macvdmtool
   cd macvdmtool
   make
   ```

3. Enter serial debug mode:
   ```bash
   sudo ./macvdmtool reboot serial
   ```

4. Connect to serial console:
   ```bash
   picocom /dev/cu.debug-console -b 115200
   ```

### Commands
| Command | Action |
|---------|--------|
| `serial` | Enter serial mode |
| `reboot` | Restart target |
| `reboot serial` | Restart into serial mode |
| `dfu` | Enter DFU mode |

## Method 2: DIY Arduino/FUSB302 Interface

### Components
- Arduino (or similar microcontroller)
- FUSB302 USB-PD PHY chip
- USB Type-C breakout board
- 1.2V level shifter (UART is 1.2V logic!)

### Software
Use [vdmtool](https://github.com/AsahiLinux/vdmtool) for the Arduino firmware.

### Wiring
- Serial TX/RX on SBU1/SBU2 pins
- FUSB302 handles USB-PD negotiation

## Method 3: Central Scrutinizer Board

Pre-designed PCB using Raspberry Pi Pico:
- Level shifters included
- USB 2.0 pass-through
- Stackable design (two boards can be stacked)

## Technical Details

### UART Specs
- **Voltage:** 1.2V logic levels
- **Baud:** 115200
- **Protocol:** Standard UART

### USB-PD VDM Protocol
- Uses Apple USB ID: `0x5AC`
- VDM header format: `0x5ac8000 | command`
- Requires SOP'DEBUG/SOP''DEBUG packet tokens

### Key VDM Commands
| Command | Action |
|---------|--------|
| 0x10 | List available actions |
| 0x11 | Get action info |
| 0x12 | Execute action |

### Debug Actions
| Action ID | Function | Notes |
|-----------|----------|-------|
| 0x306 | Debug UART | Serial console, 1.2V |
| 0x4606 | Debug USB | Device ID 05ac:1881 |
| 0x0803/0x0809 | I2C buses | 3.3V, addresses 0x38/0x3f |

## Use Cases for Substrate Development

1. **Black screen debugging**: Get kernel logs when display fails
2. **Boot troubleshooting**: See early boot messages
3. **Kernel development**: Interactive debugging
4. **Recovery**: Access system when normal login fails

## Resources

- [macvdmtool](https://github.com/AsahiLinux/macvdmtool) - Mac-to-Mac serial
- [vdmtool](https://github.com/AsahiLinux/vdmtool) - Arduino/DIY firmware
- [Asahi Serial Debug Docs](https://asahilinux.org/docs/hw/soc/serial-debug/)
- [Asahi USB-PD Docs](https://asahilinux.org/docs/hw/soc/usb-pd/)

---

## Quick Reference

```bash
# On host Mac (connected to target via USB-C)
git clone https://github.com/AsahiLinux/macvdmtool && cd macvdmtool && make
sudo ./macvdmtool reboot serial
picocom /dev/cu.debug-console -b 115200

# To exit picocom: Ctrl-A, Ctrl-X
```
