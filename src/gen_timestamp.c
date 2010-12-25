#include <time.h>
#include <string.h>

/* Cross-platform timestamp generation, since Time.local uses localtime_r, which
   is not available under MinGW since Win32's localtime is thread-safe */
char *gen_timestamp(char *format,time_t time) {
#ifdef WINDOWS
	struct tm *timestruct = malloc(sizeof(struct tm));
	localtime_r(&time,timestruct);
	char out[200];
	strftime(out,sizeof(out),format,timestruct);
	return strdup(out);
#else
	struct tm *timestruct = localtime(&time);
	char *out = malloc(200*sizeof(char));
	strftime(out,200*sizeof(char),format,timestruct);
	char *result = strdup(out);
	free(out);
	return result;
#endif
}
