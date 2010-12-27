#include <time.h>
#include <string.h>
#include "config.h"
#ifndef WINDOWS
#include <stdlib.h>
#else
#include <shellapi.h>
#endif

/* Cross-platform timestamp generation, since Time.local uses localtime_r, which
   is not available under MinGW since Win32's localtime is thread-safe */
char *gen_timestamp(char *format,time_t time) {
#ifdef WINDOWS
	struct tm *timestruct = localtime(&time);
	char out[200];
	strftime(out,sizeof(out),format,timestruct);
	return strdup(out);
#else
	char *out = malloc(200*sizeof(char));
	struct tm *timestruct = malloc(sizeof(struct tm));
	localtime_r(&time,timestruct);
	strftime(out,200*sizeof(char),format,timestruct);
	char *result = strdup(out);
	free(out);
	return result;
#endif
}

#ifdef WINDOWS
/* Opening a file never has been so easy! */
void open_url_in_browser(char *url) {
	ShellExecute(NULL,"open",url,NULL,NULL,SW_SHOW);
}
#endif
