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
```

Palette: `⌘1`–`⌘4` switch direction, `⌘⇧L` shows or hides the palette, `⌘K` search where a
direction has one, `Esc` closes whatever is open.
