---
layout: site
title: XSIRC version 0.5 released
date: 2010-11-30 01:50
---

Version 0.5 has been released. This version adds tab completion and editable slash-commands (macros), as well as GUI and code improvements. This version requires a fixed GTK+ vapi file which still hasn't been applied to the Vala tree; get the fixed file [here](http://ahb.me/11-h) and extract it to `/usr/share/vala-0.10/vapi`.

Download links: [.tar.gz](https://github.com/NieXS/XSIRC/tarball/v0.5) [.zip](https://github.com/NieXS/XSIRC/zipball/v0.5)

Changes since version 0.4:
* Added macros
* Added macro preferences window
* Fixed PART message being added to view after the view was destroyed
* Fixed facepalmy code
* Made server connection dialog more user-friendly
* Added test highlight system
* Unhardcoded prefwindow UI definition
* Changed server-switching shortcut to Ctrl-Alt-, and Ctrl-Alt-.
* Changed the text entry from a Gtk.TextView to a Gtk.Entry
* Added Plugin API, still kinda useless
* Handled numerical replies 307, 265 and 266
* Added open second-to-last link
