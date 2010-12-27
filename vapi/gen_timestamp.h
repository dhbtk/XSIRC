#include <time.h>

char *gen_timestamp(char *format,time_t time);

#ifdef WINDOWS
void open_url_in_browser(char *);
#endif
