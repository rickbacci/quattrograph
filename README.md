# Quattrograph

A small Omarchy drawing toy. Live sliders for a hypotrochoid (or epitrochoid), theme-aware ink, and up to 12 saved favorites.

## Install

```sh
omarchy plugin add https://github.com/<you>/quattrograph.git --enable
omarchy plugin enable richardb-quattrograph --section right
```

Click **QG** on the bar. Esc or the dimmed edge closes it.

You can also summon it:

```sh
omarchy-shell shell summon richardb-quattrograph '{}'
```

Optional local bind (not part of the plugin):

```lua
o.bind("SUPER + SHIFT + I", "Quattrograph", "omarchy-shell -q shell toggle richardb-quattrograph")
```

## Favorites

Looks you save are stored in `~/.config/omarchy/quattrograph.json`, outside the plugin checkout, so plugin updates do not wipe them.

## Remove

```sh
omarchy plugin remove richardb-quattrograph --yes
```
