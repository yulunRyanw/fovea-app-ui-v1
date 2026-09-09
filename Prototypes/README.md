# Fovea Lab

Running prototypes of four front-page directions (Paper, Studio, Spaces, Threads) behind one
control panel. Separate package; nothing here ships. Shared files under `FoveaLab/Shared` are
copies of their shipping counterparts and are allowed to drift.

```bash
cd Prototypes
swift run FoveaLab                      # opens docked under the notch, palette alongside
swift run FoveaLab --direction threads  # paper | studio | spaces | threads
swift run FoveaLab --undocked
swift run FoveaLab --snapshot shots     # renders every direction to PNG and exits
swift run FoveaLab --smoke              # drives every palette action on the live window, logs, exits 0 on pass
```

Set `FOVEA_LAB_LOG=1` to print the dock geometry on open. The palette sits beside the window when
the display has room and tucks into the bottom-right corner when it does not (a 13-inch display).

Palette: `⌘1`–`⌘4` switch direction, `⌘⇧L` shows or hides the palette, `⌘K` search where a
direction has one, `Esc` closes whatever is open.
