#!/usr/bin/env python
# wscript
#
# Copyright (c) 2010 Eduardo Niehues
# Distributed under the New BSD License; see LICENSE for details.
import intltool

APPNAME = "XSIRC"
VERSION = "0.1"
# Shamefully stolen from midori's wscript
try:
	git = Utils.cmd_output(['git','rev-parse','--short','HEAD'],silent=True)
	if git:
		VERSION = (VERSION + '-' + git).strip()
except:
	pass


top = "."
out = "build"

def set_options(opt):
	opt.tool_options('compiler_cc')
	opt.tool_options('vala')

def configure(conf):
	conf.check_tool('compiler_cc cc vala') # intltool later too
	conf.check_cfg(package='glib-2.0',uselib_store='GLIB',atleast_version='2.10.0',mandatory=1,args='--cflags --libs')
	conf.check_cfg(package='gtk+-2.0',uselib_store='GTK',atleast_version='2.10.0',mandatory=1,args='--cflags --libs')
	conf.check_cfg(package='gio-2.0',uselib_store='GIO',atleast_version='2.10.0',mandatory=1,args='--cflags --libs')
	conf.check_cfg(package='gee-1.0',uselib_store='GEE',atleast_version='0.5.0',mandatory=1,args='--cflags --libs')
	conf.define('PACKAGE_NAME',APPNAME)
	conf.define('APPNAME',APPNAME)
	conf.define('VERSION',VERSION)
	conf.define('GETTEXT_PACKAGE',APPNAME)
	conf.write_config_header('config.h')
	conf.env.append_value('VALAFLAGS','-g')
	conf.env.append_value('CCFLAGS','-g')
	#conf.env.append_value('CCFLAGS','-I/usr/include/gdk-pixbuf-2.0')
	conf.env.append_value('LDFLAGS','-g')
	
def build(bld):
	bld.add_subdirs('src')
	#bld.add_subdirs('po')
	bld.install_files(bld.env['PREFIX']+'/share/licenses/xsirc','LICENSE') # Arch Linux thing
