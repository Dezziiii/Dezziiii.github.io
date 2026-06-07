# Casio World Time — Garmin Forerunner 165 watch face

A Garmin Connect IQ **watch face** for the **Forerunner 165 / 165 Music**,
styled after the classic **Casio AE1200WH-1A** ("World Time" / Royale).

![preview](preview.svg)

## What it shows

It recreates the watch as a **black resin case** with printed text
(`CASIO`, `WORLD TIME`, `WR 100M`, `AE-1200WH`) wrapped around a rounded
**grey-green positive-LCD panel**. The time is drawn as **true hand-built
7-segment digits** with faint "ghost" off-segments, exactly like a real LCD.

It recreates the **physical watch**, not just a screen layout: a black resin
case with the four metal **pushers** and their guards, resin **strap lugs**
with keeper loops, printed **bezel text**, and a **recessed cushion LCD** in
the olive-grey positive-LCD colour. The time is drawn as hand-built
**7-segment digits** with faint "ghost" off-segments, like a real LCD.

| Area | Content |
|------|---------|
| **Top-left field** | Live **heart rate + daily steps** (see note below). |
| **Centre** | The Casio **dot-matrix world map**, shaded for **day/night** with **sun + moon markers** and a home-city pointer, computed from the current UTC time. |
| **Top-right field** | **Active alarms** — a bell + the number of alarms currently set. |
| **Info row** | Day-of-week · home **city code** (LON/NYC/TYO…) · date. |
| **Main** | Large **7-segment** `HH:MM` with small ticking **seconds**. |
| **Status strip** | **Bluetooth** + **battery** gauge. |

The face keeps the LCD look on at all times, including the always-on display.

### The "world time" touch

Because it's a *World Time* watch, the map isn't just decoration: the night
hemisphere is drawn in fainter dots and the daylight hemisphere in bold dots,
with a sun over the sub-solar point and a moon opposite it — so at a glance
you can see where on Earth it's day or night.

> **Note on bezel print:** Garmin's smallest system font is larger than real
> resin printing, so the case text is chunkier on-device than in `preview.svg`.
> A custom bitmap font could match it exactly — see "ideas" at the bottom.

## Settings (Garmin Connect → Watch Face settings)

- **Force 24-hour clock** — override the system time format.
- **Show seconds** — toggle the ticking seconds counter.

## Two honest hardware notes

1. **Top-left window** — the Forerunner 165 has **no magnetometer**, so no
   live compass heading is available to a watch face. Rather than fake it,
   that window is repurposed as a live activity readout: current **heart
   rate** and **daily step count**. (On a watch with a compass, e.g.
   Fenix/Epix, this could instead be driven by `Sensor` heading.)
2. **Alarms** — Connect IQ exposes only the **number** of active alarms
   (`DeviceSettings.alarmCount`) to a watch face, not the individual alarm
   times. The top-right window shows that count.

## Building & installing

You need the [Connect IQ SDK](https://developer.garmin.com/connect-iq/sdk/)
and a developer key.

```bash
# Generate a signing key once:
openssl genrsa -out developer_key.pem 4096
openssl pkcs8 -topk8 -inform PEM -outform DER -in developer_key.pem \
        -out developer_key.der -nocrypt

# Build a sideloadable .prg for the FR165:
monkeyc -o bin/CasioWorldTime.prg \
        -f monkey.jungle \
        -y developer_key.der \
        -d fr165

# Run it in the simulator:
connectiq            # launch the simulator, then:
monkeydo bin/CasioWorldTime.prg fr165
```

To install on the watch, copy the `.prg` to `GARMIN/APPS/` on the device over
USB, or build an `.iq` package with `monkeyc -e ...` for the Connect IQ Store.

### Quickest path: VS Code

Install the **Monkey C** extension, open this folder, run
**Connect IQ: Build Current Project** (or **Run** to launch the simulator),
and pick **fr165**.

## Project layout

```
manifest.xml                     app id, type=watchface, fr165/fr165m
monkey.jungle                    build config
source/CasioWorldTimeApp.mc      AppBase entry point
source/CasioWorldTimeView.mc     the watch face (all drawing)
resources/strings/strings.xml    UI strings
resources/settings/              user-configurable properties + settings
resources/drawables/             launcher icon
tools/make_icon.py               regenerates the launcher icon (stdlib only)
tools/preview.py                 regenerates preview.svg (stdlib only)
```

`preview.svg` is a mockup that mirrors the on-watch layout and the exact map
data, for previewing without the simulator. The device is the source of truth.
