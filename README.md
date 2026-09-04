# Quattrograph

A small Omarchy drawing toy. The curve draws itself on a full sheet of paper. **Wander** plays named looks, **Save** keeps one, and a tool rest along the bottom holds pace and the live sliders. Looks and ink sit in popovers, not a scrolling menu.

## Install

```sh
omarchy plugin add https://github.com/<you>/quattrograph.git --enable
omarchy plugin enable richardb-quattrograph --section right
```

Click **QG** on the bar. Esc or the dimmed edge closes it. Space toggles Wander; S saves. **Looks** and **Ink** open up from the bar.

You can also summon it:

```sh
omarchy-shell shell summon richardb-quattrograph '{}'
```

Optional local bind (not part of the plugin):

```lua
o.bind("SUPER + SHIFT + I", "Quattrograph", "omarchy-shell -q shell toggle richardb-quattrograph")
```

## Tests

Omarchy does not run plugin unit tests. The contract check is `omarchy plugin validate`. Math and favorites JSON are covered by Node:

```sh
node tests/run.mjs
omarchy plugin validate .
```

## Favorites

Looks you save are stored in `~/.config/omarchy/quattrograph.json`, outside the plugin checkout, so plugin updates do not wipe them.

## Remove

```sh
omarchy plugin remove richardb-quattrograph --yes
```
