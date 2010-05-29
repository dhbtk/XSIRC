require 'rake/clean'
CLEAN   = FileList["build/xsirc*"]
SRC     = FileList["src/*.vala"]
DEPS    = %w[gee-1.0 gio-2.0 posix gtk+-2.0]
CC_OPTS = nil

task :default => "build/xsirc"

file "build/xsirc" => SRC do
	sh "valac #{DEPS.empty? ? '' : '--pkg '+DEPS.join(' --pkg ')} -o build/xsirc #{SRC.join(' ')}#{CC_OPTS ? ' -X '+CC_OPTS : ''}"
end

task :debug do
	sh "valac #{DEPS.empty? ? '' : '--pkg '+DEPS.join(' --pkg ')} -g --save-temps --thread -o build/xsirc_dbg #{SRC.join(' ')}#{CC_OPTS ? ' -X '+CC_OPTS : ''}"
end
