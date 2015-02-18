#ifndef SENSING_H_
#define SENSING_H_

#include <IPDispatch.h>
typedef nx_struct statistics{
  nx_uint16_t thresHold;
  nx_uint16_t value;
  nx_uint16_t type;
  nx_uint16_t sender;
} settings_t;

enum{
  CALIBRATION = 1,
  BEATS = 2,
  THRESHOLD=3,
  
};

define REPORT_DEST "fec0::100" //not used since we multicast all information 
#define MULTICAST "ff02::1"

#endif
