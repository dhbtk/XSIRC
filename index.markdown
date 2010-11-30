---
layout: site
---

About
-----

XSIRC is a GTK+-based IRC client for Linux and Windows (partially functional). It is lightweight, written in Vala (easier to maintain, C-library-compatible) and easy to use. It is still in its infancy; contributions are welcomed.

### Screenshots

<table>
<tr>
<td>
<a target='_blank' href='http://img87.imageshack.us/img87/4462/xsirccurrent.png'><img src='http://img87.imageshack.us/img87/4462/xsirccurrent.th.png' border='0'/></a></td>
<td>
<a target='_blank' href='http://img690.imageshack.us/img690/8237/xsircprefs.png'><img src='http://img690.imageshack.us/img690/8237/xsircprefs.th.png' border='0'/></a></td>
</tr>
</table>

Download
--------

The latest version is 0.5 ([.tar.gz](https://github.com/NieXS/XSIRC/tarball/v0.5) [.zip](https://github.com/NieXS/XSIRC/zipball/v0.5)). The client needs a fix to the GTK+ vapi that still hasn't been added to the Vala tree; get the fixed file [here](http://ahb.me/11-h) and extract it to `/usr/share/vala-0.10/vapi`.

You can download the bleeding edge git commit here: [.zip](https://github.com/NieXS/XSIRC/zipball/master) [.tar.gz](https://github.com/NieXS/XSIRC/tarball/master)

You can also get it by using git:

	git clone git://github.com/NieXS/XSIRC.git

The client's GitHub page is [here](http://github.com/NieXS/XSIRC).

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

See [Usage](manual).
