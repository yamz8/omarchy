# Backgrounds

Every theme ships with its own set of backgrounds, and you can add extras of your own in `~/.config/omarchy/backgrounds/[theme]`. If you want to add an extra background image to, say, the nord theme, you just put the file in `~/.config/omarchy/backgrounds/nord`.

You can do this most easily by going to _Install > Style > Background_ in the Omarchy Menu. That'll bring up the folder where the backgrounds for that theme is stored. Hit `Super + Shift + F` to start another file manager, find your background, copy it over.  Now it'll be included in the choices of backgrounds you can select between using `Super + Ctrl + Space`.

Backgrounds can be videos as well as stills. Drop an `mp4`, `m4v`, `mov`, `webm`, `mkv`, or `avi` file in the same folder and it appears alongside the images. Videos are played by the OWE wallpaper engine. It decodes the video once for all monitors and plays its sound through the default audio output, and it stops playback whenever nothing can see it. The lock screen draws the same decode, muted, through OWE. A video wallpaper still costs far more power than a still one.

You can find a huge collection of cool curated backgrounds on https://github.com/dharmx/walls.

Many of the backgrounds that come with the themes also have an intro: a few seconds of animation that plays once when you log in, starting from the background and settling back onto it. Turn intros off with _Trigger > Toggle > Background Intros_ in the Omarchy Menu. They also stay off while animations are off (_Trigger > Toggle > Animations_), which Omarchy does by default in a virtual machine.

You can give one of your own backgrounds an intro by putting a video with the same name in an `intros` folder next to it, like `~/.config/omarchy/backgrounds/nord/intros/lake.mp4` for `~/.config/omarchy/backgrounds/nord/lake.jpg`. Make it start on the image itself and hold it for a second before anything moves, then end on the image again, so it flows out of the background and back into it.

Video backgrounds keep a cached still on the lock screen while playback is paused or unavailable. Animated GIFs play on the desktop and show a still frame on the lock screen.
