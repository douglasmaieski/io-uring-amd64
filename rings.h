#ifndef RINGS_H
#define RINGS_H

#include <stdint.h>
#include <linux/io_uring.h>

struct rings {
  uint64_t opaque[16];
};

// returns 1 on success and 0 on failure
long rings_setup(struct rings *rings, int entries);

// returns 1 on success and 0 on failure
long rings_submit(struct rings *rings, struct io_uring_sqe *sqe);

// returns the number of items reaped
long rings_reap(struct rings *rings, struct io_uring_cqe *cqes, long max_count);

#endif
