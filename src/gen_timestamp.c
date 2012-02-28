#include <time.h>
#include <string.h>
#include "config.h"
#ifndef WINDOWS
#include <stdlib.h>
#else
#include <windows.h>
#endif

/* Cross-platform timestamp generation, since Time.local uses localtime_r, which
   is not available under MinGW since Win32's localtime is thread-safe */
char *gen_timestamp(char *format,time_t time) {
	char out[200];
	struct tm timestruct;
#ifdef WINDOWS
	timestruct = *localtime(&time);
#else
	localtime_r(&time,&timestruct);
#endif
	strftime(out,sizeof(out),format,&timestruct);
	return strdup(out);
}

#ifdef WINDOWS
void open_url_in_browser(char *url) {
	ShellExecute(NULL,"open",url,NULL,NULL,SW_SHOW);
}
#endif
