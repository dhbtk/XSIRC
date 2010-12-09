---
layout: site
title: XSIRC version 1.2 released
---

Version 1.2 has been released. This version brings some internal code changes and
customizable messages for JOINs, PARTs, KICKs and the like; look around in the
"plugins"
settings dialog.

I released version 1.1 yesterday, but the changes I made to the API broke the plugin
system. These have been fixed now.

Download links: [.tar.gz](https://github.com/NieXS/XSIRC/tarball/v1.2) [.zip](https://github.com/NieXS/XSIRC/zipball/v1.2)

Changes since version 1.0:

* The text entry is now its own class, derived from GtkEntry
* Fixed a crash bug
* Messages are now user-customizable
