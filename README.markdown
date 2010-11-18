	__  ______ ___ ____   ____ 
	\ \/ / ___|_ _|  _ \ / ___|
	 \  /\___ \| || |_) | |    
	 /  \ ___) | ||  _ <| |___ 
	/_/\_\____/___|_| \_\\____|
	XSIRC           version 0.2

XSIRC is a GTK+-based IRC client for *nix platforms. It is lightweight and uses
only stock GTK+ widgets.

Installing
==========

XSIRC depends on GTK+-2.10, and libgee-0.5. It also requires python and vala for
the compilation. Compilation is simple:

	~/xsirc $ ./waf configure
	~/xsirc $ ./waf

Installation is also simple:

	~/xsirc $ ./waf install
 
XSIRC can be uninstalled by calling ./waf uninstall.

Using it
========

Connect to a server by pressing Ctrl-Shift-O or clicking Client->Connect... in
the menu. The slash-commands are all sent directly to the server, except for /me
and /ctcp, which are helper commands. The syntax for /ctcp is:
	/ctcp <target> <message>

Contributing
============

XSIRC still has quite some features left to be added; please contribute if
you can. Suggestions, criticisms, and code are all accepted.
