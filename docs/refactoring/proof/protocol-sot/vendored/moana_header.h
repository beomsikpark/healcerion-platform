/*
 * VERBATIM excerpt - do not edit. Lifted by reconcile.py --emit-vendored.
 *
 *   repo   client/legacy/moana
 *   commit 7b26a9b27219f99b36272de3a28e566472a84a2b (origin/service_QT693)
 *   file   framework/SononClient/SononPacket.h:138-146
 *   sha256 ab958c9902f487c9 (of the excerpt below)
 *
 * This is the comparison target for verify_layout.c. Copying it by hand would
 * destroy the claim it exists to support.
 */
#ifndef HC_VENDORED_MOANA_H
#define HC_VENDORED_MOANA_H


typedef struct __common_packet_header {
    char identifier[2];
    char version[2];
    char recv_id[2];    
    unsigned short session_id; 
    unsigned short packet_type;
    unsigned int packet_body_size;
    char packet_body[1];
} __attribute__((packed)) COMMON_PACKET_HEADER;

#endif
