#include <time.h>
#include <string.h>

/* Cross-platform timestamp generation, since Time.local uses localtime_r, which
   is not available under MinGW since Win32's localtime is thread-safe */
char *gen_timestamp(char *format,time_t time) {
#ifdef WINDOWS
	struct tm *timestruct = malloc(sizeof(struct tm));
	localtime_r(&time,timestruct);
#else
	struct tm *timestruct = localtime(&time);
#endif
	char out[200];
	strftime(out,sizeof(out),format,timestruct);
	return strdup(out);
}
