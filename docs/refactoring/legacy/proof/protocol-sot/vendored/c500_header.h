/*
 * VERBATIM excerpt - do not edit. Lifted by reconcile.py --emit-vendored.
 *
 *   repo   device/legacy/500c-sn-fw
 *   commit ca2096a26bb1f64d53a7fe35f43bbe0c5606daf8 (origin/FW_1_1_8_0)
 *   file   src/App/include/USSCustomCommand.h:3029-3036
 *   sha256 2476d1b99ad7767d (of the excerpt below)
 *
 * This is the comparison target for verify_layout.c. Copying it by hand would
 * destroy the claim it exists to support.
 */
#ifndef HC_VENDORED_C500_H
#define HC_VENDORED_C500_H

#ifndef HC_VENDORED_INT_SHIM
#define HC_VENDORED_INT_SHIM
typedef unsigned int        U32;
typedef unsigned short      U16;
typedef unsigned char       U8;
#endif

typedef struct  __attribute__ ((packed)) {
	U8 identifier[2];
	U8 version[2];
	U16 recv_id;
	U16 session_id;
	U16 packet_type;
	U32 packet_body_size;
}PACKET_HEADER_S;

#endif
