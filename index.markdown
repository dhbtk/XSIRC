---
layout: site
---

About
-----

XSIRC is a GTK+-based IRC client for Linux and Windows (partially functional). It is lightweight, written in Vala (easier to maintain, C-library-compatible) and easy to use. It is still in its infancy; contributions are welcomed.


Download
--------

You can download the bleeding edge git commit here: [.zip](https://github.com/NieXS/XSIRC/zipball/master) [.tar.gz](https://github.com/NieXS/XSIRC/tarball/master)

You can also get it by using git:

	git clone git://github.com/NieXS/XSIRC.git

The client's GitHub page is [here.](http://github.com/NieXS/XSIRC)

Installation
------------

XSIRC depends on GTK+ 2.10 and libgee-0.5. For compilation, Python and the Vala compiler are required. In Debian and Ubuntu, the packages required for compilation are:

	build-essential vala libgtk2.0-dev libgee-dev

The steps for installation are:

	~/XSIRC$ ./waf configure
	~/XSIRC$ ./waf build
	~/XSIRC$ ./waf install

Uninstallation is also easy:

	~/XSIRC$ ./waf uninstall


Usage
-----

See [Usage](/manual.html).
