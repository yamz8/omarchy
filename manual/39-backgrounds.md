# Backgrounds

Every theme ships with its own set of backgrounds, and you can add extras of your own in `~/.config/omarchy/backgrounds/[theme]`. If you want to add an extra background image to, say, the nord theme, you just put the file in `~/.config/omarchy/backgrounds/nord`.

You can do this most easily by going to _Install > Style > Background_ in the Omarchy Menu. That'll bring up the folder where the backgrounds for that theme is stored. Hit `Super + Shift + F` to start another file manager, find your background, copy it over.  Now it'll be included in the choices of backgrounds you can select between using `Super + Ctrl + Space`.

You can find a huge collection of cool curated backgrounds on https://github.com/dharmx/walls.

## Animated login intro

When the desktop starts, Omarchy briefly brings the selected background forward with a subtle camera movement, then settles on the exact image and fades into the normal desktop. The animation runs once per login and does not replay when the Omarchy shell is restarted. Automatic playback is skipped when Hyprland animations are disabled.

Turn it on or off with:

```bash
omarchy toggle login-intro on
omarchy toggle login-intro off
```

The built-in motion works with every background automatically. A manual preview still works when automatic animation is disabled. You can replace the intro for the currently selected image with a short video:

```bash
omarchy theme intro set ~/Videos/my-intro.mp4
omarchy theme intro preview
```

Omarchy stores the video against the image's content rather than its filename. Changing to another background therefore uses that background's own intro, or the built-in motion when no custom video exists. Videos are normalized to a silent clip of up to 30 seconds, cropped in the same way as the wallpaper, and faded into the actual selected image at the end so the handoff remains exact. For the smoothest result, make the first and final frames match the background.

Remove the custom video for the current image with:

```bash
omarchy theme intro remove
```
