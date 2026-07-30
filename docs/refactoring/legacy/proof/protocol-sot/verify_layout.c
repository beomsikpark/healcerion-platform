/*
 * verify_layout.c - prove that the canonical hc_header_t is byte-identical to all three
 * original declarations, and demonstrate the one place where they are NOT equivalent.
 *
 * The originals are not retyped here; the headers under vendored/ are verbatim excerpts
 * lifted from the mirrors at pinned commits by `reconcile.py --emit-vendored`.
 *
 *   make verify        # compile (the layout claim is a compile-time assertion) and run
 */
#include <stdio.h>
#include <stddef.h>
#include <string.h>

#include "include/hc_protocol.h"

/* belle 과 500C 가 같은 이름을 쓴다. 원본을 고치지 않고 토큰만 갈아끼운다. */
#define PACKET_HEADER_S BELLE_PACKET_HEADER_S
#include "vendored/belle_header.h"
#undef PACKET_HEADER_S

#define PACKET_HEADER_S C500_PACKET_HEADER_S
#include "vendored/c500_header.h"
#undef PACKET_HEADER_S

#include "vendored/moana_header.h"

typedef struct BELLE_PACKET_HEADER_S belle_t;
typedef C500_PACKET_HEADER_S         c500_t;
typedef COMMON_PACKET_HEADER         moana_t;

/* ---- claim 1: every field sits at the same offset in all four declarations --------- */

#define SAME_OFFSET(field, off)                                                       \
    _Static_assert(offsetof(hc_header_t, field) == (off), "canonical " #field);       \
    _Static_assert(offsetof(belle_t, field)     == (off), "belle "     #field);       \
    _Static_assert(offsetof(c500_t, field)      == (off), "c500 "      #field);       \
    _Static_assert(offsetof(moana_t, field)     == (off), "moana "     #field)

SAME_OFFSET(identifier,       0);
SAME_OFFSET(version,          2);
SAME_OFFSET(recv_id,          4);
SAME_OFFSET(session_id,       6);
SAME_OFFSET(packet_type,      8);
SAME_OFFSET(packet_body_size, 10);

#define SAME_WIDTH(field, n)                                                          \
    _Static_assert(sizeof(((hc_header_t *)0)->field) == (n), "canonical " #field);    \
    _Static_assert(sizeof(((belle_t *)0)->field)     == (n), "belle "     #field);    \
    _Static_assert(sizeof(((c500_t *)0)->field)      == (n), "c500 "      #field);    \
    _Static_assert(sizeof(((moana_t *)0)->field)     == (n), "moana "     #field)

SAME_WIDTH(identifier,       2);
SAME_WIDTH(version,          2);
SAME_WIDTH(recv_id,          2);
SAME_WIDTH(session_id,       2);
SAME_WIDTH(packet_type,      2);
SAME_WIDTH(packet_body_size, 4);

/* ---- claim 2: the wire header is 14 bytes ----------------------------------------- */

_Static_assert(sizeof(hc_header_t) == HC_HEADER_SIZE, "canonical header is 14 bytes");
_Static_assert(sizeof(belle_t)     == 14,             "belle header is 14 bytes");
_Static_assert(sizeof(c500_t)      == 14,             "c500 header is 14 bytes");

/*
 * moana 는 예외다 — 가변 본문 char packet_body[1] 을 구조체 안에 넣어 sizeof 가 15 다.
 * 그래서 앱 코드는 sizeof 를 쓰지 않고 상수 COMMON_PACKET_HEADER_SIZE(14) 를 쓴다.
 * 앞의 6개 필드 오프셋이 같으므로 wire 호환은 유지된다. 사실대로 기록해 둔다.
 */
_Static_assert(sizeof(moana_t) == 15, "moana folds the body into the struct");
_Static_assert(offsetof(moana_t, packet_body) == 14, "moana body starts right after 14 bytes");

/* ---- claim 3: recv_id is where the two models actually diverge --------------------- */
/*
 * device  belle-fw sonon_receive.cpp:79  header->recv_id = HER_TARGET_ID_CLIENT;   (U16)
 * client  moana    BasePacket.cpp:731    if (m_pkt_head->recv_id[1] == target_id)  (char[2])
 *
 * On little-endian the device puts the target in byte 0, so the client's byte-1 test can
 * only fire when target_id == 0 - and target_id is only ever 1 or 2. The check is dead;
 * what actually validates the target is the 6-byte memcmp above it, which happens to
 * cover recv_id[0]. 지금 동작은 맞다. 검사가 죽어 있을 뿐이다.
 */
#define MOANA_ERR_OK                0
#define MOANA_ERR_INVALID_HEADER    1
#define MOANA_ERR_INVALID_TARGET_ID 2

/* BasePacket.cpp:619-644 initPacketHeaderInfo + :722-733 validation, transcribed. */
static int moana_validate(const unsigned char *wire, unsigned short target_id)
{
    unsigned char context[6];
    const moana_t *head = (const moana_t *)wire;

    context[0] = 'H';                       /* HC_HEADER_PREFIX0     */
    context[1] = 'C';                       /* HC_HEADER_PREFIX1     */
    context[2] = 1;                         /* HC_HEADER_VER_MAJOR, 500L */
    context[3] = 0;                         /* HC_HEADER_VER_MINOR   */
    context[4] = (unsigned char)target_id;  /* context[4] = target_id */
    context[5] = 0;

    if (memcmp(head, context, 6) != 0)
        return MOANA_ERR_INVALID_HEADER;
    if (head->recv_id[1] == target_id)
        return MOANA_ERR_INVALID_TARGET_ID;
    return MOANA_ERR_OK;
}

static void build_device_response(unsigned char *wire)
{
    belle_t h;
    memset(&h, 0, sizeof(h));
    h.identifier[0] = 'H';
    h.identifier[1] = 'C';
    h.version[0]    = 1;                        /* HER_PROTOCOL_VER_MAJOR */
    h.version[1]    = 0;                        /* HER_PROTOCOL_VER_MINOR */
    h.recv_id       = HC_TARGET_ID_CLIENT;      /* sonon_receive.cpp:79   */
    h.session_id    = 0;
    h.packet_type   = HC_PACKET_TYPE_DEVICE_RESP;
    h.packet_body_size = 4;
    memcpy(wire, &h, sizeof(h));
}

int main(void)
{
    unsigned char wire[64];
    const hc_header_t *canon;
    int rc;

    printf("field             offset  canonical  belle  moana  c500\n");
#define ROW(f) printf("%-16s %6zu  %9zu  %5zu  %5zu  %4zu\n", #f, offsetof(hc_header_t, f), \
                      offsetof(hc_header_t, f), offsetof(belle_t, f),                       \
                      offsetof(moana_t, f), offsetof(c500_t, f))
    ROW(identifier); ROW(version); ROW(recv_id);
    ROW(session_id); ROW(packet_type); ROW(packet_body_size);
#undef ROW
    printf("%-16s %6s  %9zu  %5zu  %5zu  %4zu\n", "sizeof", "-",
           sizeof(hc_header_t), sizeof(belle_t), sizeof(moana_t), sizeof(c500_t));
    printf("  (moana is 15: it folds char packet_body[1] into the struct and uses the\n"
           "   constant COMMON_PACKET_HEADER_SIZE=%d instead of sizeof)\n\n", HC_HEADER_SIZE);

    /* The device encodes a real response; the canonical header decodes it. */
    build_device_response(wire);
    canon = (const hc_header_t *)wire;
    printf("device response decoded through the canonical header:\n");
    printf("  identifier=%c%c version=%u.%u recv_id=0x%04X packet_type=0x%04X body=%u\n",
           canon->identifier[0], canon->identifier[1], canon->version[0], canon->version[1],
           canon->recv_id, canon->packet_type, canon->packet_body_size);
    printf("  wire bytes at offset 4..5 = {0x%02X, 0x%02X}\n\n", wire[4], wire[5]);

    if (canon->recv_id != HC_TARGET_ID_CLIENT) {
        printf("FAIL: canonical decode disagrees with the device encode\n");
        return 1;
    }

    /* Now run moana's own validation over the same bytes. */
    printf("moana validation of those same bytes (target_id=CLIENT=0x%04X):\n",
           HC_TARGET_ID_CLIENT);
    rc = moana_validate(wire, HC_TARGET_ID_CLIENT);
    printf("  result = %d (%s)\n", rc, rc == MOANA_ERR_OK ? "accepted" : "rejected");
    printf("  recv_id[1] = 0x%02X, target_id = 0x%02X -> the explicit target check cannot\n"
           "  fire; the 6-byte memcmp is what actually validates the target.\n",
           wire[5], HC_TARGET_ID_CLIENT);

    if (rc != MOANA_ERR_OK) {
        printf("\nFAIL: shipped client would reject a shipped device response\n");
        return 1;
    }

    printf("\nOK: 14-byte layout identical across all four declarations;\n"
           "    behaviour preserved; recv_id target check recorded as dead code.\n");
    return 0;
}
