#!/usr/bin/env python
# wscript
#
# Copyright (c) 2010 Eduardo Niehues
# Distributed under the New BSD License; see LICENSE for details.
#import intltool
import os
import Options
APPNAME = "XSIRC"
VERSION = "1.2"
# Shamefully stolen from midori's wscript
try:
	git = Utils.cmd_output(['git','rev-parse','--short','HEAD'],silent=True)
	if git:
		VERSION = (VERSION + '-' + git).strip()
except:
	pass


top = "."
out = "build"

def is_mingw (env):
	if 'CC' in env:
		cc = env['CC']
		if not isinstance (cc, str):
			cc = ''.join (cc)
		return cc.find ('mingw') != -1# or cc.find ('wine') != -1
	return False
def options(opt):
	opt.tool_options('compiler_c')
	opt.tool_options('vala')
	opt.load('gnu_dirs')

def configure(conf):
	conf.check_tool('compiler_c vala')
	conf.load('gnu_dirs intltool')
	if is_mingw(conf.env):
		if not 'AR' in os.environ and not 'RANLIB' in os.environ:
			conf.env['AR'] = os.environ['CC'][:-3] + 'ar'
		Options.platform = 'win32'
		conf.env['program_PATTERN'] = '%s.exe'
		conf.env.append_value('CCFLAGS','-mms-bitfields')
		conf.env.append_value ('CCFLAGS', '-mwindows')
		conf.env["windows"] = 'yes'
		conf.define('OS','win32')
		conf.env.append_value('VALAFLAGS',['-D','WINDOWS'])
		conf.env['PREFIX'] = '.' # hacky, I know
		conf.env['LOCALEDIR'] = 'share/locale'
	else:
		conf.define('OS','unix')
	conf.check_cfg(package='glib-2.0',uselib_store='GLIB',atleast_version='2.10.0',mandatory=1,args='--cflags --libs')
	conf.check_cfg(package='gtk+-2.0',uselib_store='GTK',atleast_version='2.10.0',mandatory=1,args='--cflags --libs')
	conf.check_cfg(package='gio-2.0',uselib_store='GIO',atleast_version='2.10.0',mandatory=1,args='--cflags --libs')
	conf.check_cfg(package='gmodule-2.0',uselib_store='GMODULE',atleast_version='2.10.0',mandatory=1,args='--cflags --libs')
	conf.check_cfg(package='gee-1.0',uselib_store='GEE',atleast_version='0.5.0',mandatory=1,args='--cflags --libs')
	if not is_mingw(conf.env):
		conf.check_cfg(package='libnotify',uselib_store='NOTIFY',atleast_version='0.5.0',mandatory=1,args='--cflags --libs')
	app = "xsirc"
	conf.define('PACKAGE_NAME',app)
	conf.define('APPNAME',APPNAME)
	conf.define('VERSION',VERSION)
	conf.define('GETTEXT_PACKAGE',app)
	conf.define('PREFIX',conf.env['PREFIX'])
	conf.define('LOCALE_DIR',conf.env['LOCALEDIR'])
	conf.write_config_header('config.h')
	conf.env['PACKAGE'] = 'xsirc'
	conf.env.append_value('VALAFLAGS','-g')
	conf.env.append_value('CCFLAGS','-g')
	conf.env.append_value('CCFLAGS','-Ivapi/')
	conf.env.append_value('LDFLAGS','-g')
	
def build(bld):
	bld.add_subdirs('src')
	bld.add_subdirs('plugins')
	bld(features='intltool_po',appname='xsirc',podir='po',install_path=bld.env['LOCALEDIR'])
	bld.install_files(bld.env['PREFIX']+'/share/licenses/xsirc','LICENSE') # Arch Linux thing
	# Icon
	bld.install_files(bld.env['PREFIX']+'/share/pixmaps','xsirc.png')
	# Preferences ui
	bld.install_files(bld.env['PREFIX']+'/share/xsirc','src/prefwindow.ui')
	bld.install_files(bld.env['PREFIX']+'/share/xsirc','src/pluginprefwindow.ui')
	bld.new_task_gen(features='subst',source='xsirc.desktop.in',target='xsirc.desktop')
	bld.install_files(bld.env['PREFIX']+'/share/applications','xsirc.desktop')
