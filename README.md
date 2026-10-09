# Quattrograph

A hypotrochoid that draws itself. Click the astroid on the bar.

## Install

```sh
omarchy plugin add https://github.com/rickbacci/quattrograph.git --enable
```

The installer asks which side of the bar. The default is the right. Esc, or a click on the dimmed edge, closes it.

## Draw

**Inside** and **Outside** choose which way the circle rolls. **Pace**, **R**, **r**, and **p** shape the figure. A finished figure stays where the pen stopped.

**Wander** draws a new figure, then the next. **Favorites** does that with the ones you saved, and it appears after the first save. Both keep the width, ink, and pace you already set.

**Save** keeps the current figure, up to 12. **Saved** lists them. Click a name there to load that figure, including the width and ink it was saved with.

**Ink** is **Theme** or **Rainbow**, and that sheet holds the width.

Space toggles Wander. S saves.

Saved figures live in `~/.config/omarchy/quattrograph.json`, outside the plugin, so an update does not wipe them.

```sh
omarchy-shell shell summon richardb-quattrograph '{}'
```

## Remove

```sh
omarchy plugin remove richardb-quattrograph --yes
```

## Tests

```sh
node tests/run.mjs
omarchy plugin validate .
```
