#include <time.h>

struct tm* make_localtime(time_t timep,struct tm* s) {
	*s = *localtime(&timep);
	return localtime(&timep);
}
