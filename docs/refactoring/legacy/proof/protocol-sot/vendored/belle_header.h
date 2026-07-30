/*
 * VERBATIM excerpt - do not edit. Lifted by reconcile.py --emit-vendored.
 *
 *   repo   device/legacy/belle-fw
 *   commit b6aaa3d41d2aa4178841db8bc91b02678cc89dfb (origin/production-fw-ver2.0)
 *   file   sonon/sonon_receive.h:2210-2217
 *   sha256 8961020ebc9d363b (of the excerpt below)
 *
 * This is the comparison target for verify_layout.c. Copying it by hand would
 * destroy the claim it exists to support.
 */
#ifndef HC_VENDORED_BELLE_H
#define HC_VENDORED_BELLE_H

#ifndef HC_VENDORED_INT_SHIM
#define HC_VENDORED_INT_SHIM
typedef unsigned int        U32;
typedef unsigned short      U16;
typedef unsigned char       U8;
#endif

struct __attribute__ ((packed)) PACKET_HEADER_S {
	U8 identifier[2];
	U8 version[2];
	U16 recv_id;
	U16 session_id;
	U16 packet_type;
	U32 packet_body_size;
};

#endif
