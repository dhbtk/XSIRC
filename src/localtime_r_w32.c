#include <time.h>

struct tm* make_localtime(time_t timep,struct tm* s) {
	return localtime(&timep);
}
