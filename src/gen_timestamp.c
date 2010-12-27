#include <time.h>
#include <string.h>
#ifndef WINDOWS
#include <stdlib.h>
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
