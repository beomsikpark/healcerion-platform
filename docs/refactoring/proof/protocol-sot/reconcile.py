#!/usr/bin/env python3
"""HC protocol: reconcile the three original declarations and generate the canonical header.

Reads the original headers straight out of the read-only Phabricator mirrors at pinned
commits, so every constant in the generated header is traceable to a source line.

  ./reconcile.py --report          # divergence report
  ./reconcile.py --emit-header     # write include/hc_protocol.h
  ./reconcile.py --check           # fail if the checked-in header is stale
"""
import argparse
import collections
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
DEFAULT_ROOT = os.path.abspath(os.path.join(HERE, '..', '..', '..', '..'))

# 원본 3벌 — 커밋 SHA 로 고정한다. 브랜치 이름으로 두면 미러 동기화 때 조용히 바뀐다.
SOURCES = {
    'belle': dict(
        repo='device/legacy/belle-fw',
        commit='b6aaa3d41d2aa4178841db8bc91b02678cc89dfb',
        branch='origin/production-fw-ver2.0',
        path='sonon/sonon_receive.h',
        role='device (belle 500L, shipping)'),
    'moana': dict(
        repo='client/legacy/moana',
        commit='7b26a9b27219f99b36272de3a28e566472a84a2b',
        branch='origin/service_QT693',
        path='framework/SononClient/SononPacket.h',
        role='client (Qt, shipping / spec SOT)'),
    'c500': dict(
        repo='device/legacy/500c-sn-fw',
        commit='ca2096a26bb1f64d53a7fe35f43bbe0c5606daf8',
        branch='origin/FW_1_1_8_0',
        path='src/App/include/USSCustomCommand.h',
        role='device (500C, out of scope - reported only)'),
}

# 정본에 넣는 것은 belle + moana 뿐이다. 500C 는 범위 밖이라 보고서에만 올린다.
CANONICAL_SOURCES = ('belle', 'moana')

# 원본 구조체 선언을 있는 그대로 떠 오는 구간. verify_layout.c 의 비교 대상이 되므로
# 손으로 옮겨 적지 않는다 — 옮겨 적는 순간 "원본과 같다" 는 주장이 근거를 잃는다.
STRUCT_SPAN = {
    'belle': dict(start=r'^struct __attribute__ \(\(packed\)\) PACKET_HEADER_S \{',
                  end=r'^\};', typedefs=True),
    # moana 는 같은 선언을 Windows(#pragma pack)/그 외(__attribute__) 두 벌로 중복 기술한다.
    # 뒤엣것(비-Windows)을 뜬다.
    'moana': dict(pick='last', start=r'^typedef struct __common_packet_header \{',
                  end=r'^\} __attribute__\(\(packed\)\) COMMON_PACKET_HEADER;', typedefs=False),
    'c500':  dict(start=r'^typedef struct  __attribute__ \(\(packed\)\) \{',
                  end=r'^\}PACKET_HEADER_S;', typedefs=True),
}

# belle lib/fpga_define.h:16-18 과 500c USSCustomCommand.h:16-18 이 글자 그대로 같다(실측).
# 두 vendored 헤더가 한 TU 에 함께 들어오므로 가드를 둔다.
TYPEDEF_SHIM = ('#ifndef HC_VENDORED_INT_SHIM\n'
                '#define HC_VENDORED_INT_SHIM\n'
                'typedef unsigned int        U32;\n'
                'typedef unsigned short      U16;\n'
                'typedef unsigned char       U8;\n'
                '#endif\n')

DEFINE = re.compile(r'^\s*#define\s+([A-Z_0-9]+)\s+\(?\s*(0[xX][0-9A-Fa-f]+)\s*\)?')
SPACES = ('packet_type', 'device', 'fpga', 'target_id')


def read_source(root, key):
    s = SOURCES[key]
    repo = os.path.join(root, s['repo'])
    out = subprocess.run(['git', '-C', repo, 'show', '%s:%s' % (s['commit'], s['path'])],
                         capture_output=True)
    if out.returncode != 0:
        sys.exit('cannot read %s:%s in %s\n%s'
                 % (s['commit'][:12], s['path'], s['repo'], out.stderr.decode('utf-8', 'replace')))
    return out.stdout.decode('utf-8', 'replace')


def classify(name):
    """Return (space, short_name) or (None, None) for names outside the opcode spaces."""
    n = re.sub(r'^(HER|HC)_', '', name)
    # moana 는 HC_HEADER_TARGET_ID_*, belle 은 HER_TARGET_ID_* 로 같은 것을 다르게 부른다.
    for prefix, space in (('PACKET_TYPE_', 'packet_type'), ('DEVICE_', 'device'),
                          ('FPGA_', 'fpga'), ('TARGET_ID_', 'target_id'),
                          ('HEADER_TARGET_ID_', 'target_id')):
        if n.startswith(prefix):
            return space, n[len(prefix):]
    return None, None


def parse(text):
    """space -> value -> [full define names], in file order."""
    table = collections.defaultdict(lambda: collections.defaultdict(list))
    for line in text.splitlines():
        m = DEFINE.match(line)
        if not m:
            continue
        full, value = m.group(1), int(m.group(2), 16)
        space, _ = classify(full)
        if space:
            table[space][value].append(full)
    return table


def load(root):
    return {k: parse(read_source(root, k)) for k in SOURCES}


def union_values(tables, space, sources):
    vals = set()
    for s in sources:
        vals |= set(tables[s][space])
    return sorted(vals)


def canonical_name(tables, space, value):
    """belle wins: its READ/WRITE-explicit scheme is the more complete and self-describing one
    (83 fpga opcodes vs moana's 36). moana-only values keep their own name."""
    for src in CANONICAL_SOURCES:
        names = tables[src][space].get(value)
        if names:
            short = classify(names[0])[1]
            return 'HC_%s_%s' % (space.upper(), short)
    return None


# --------------------------------------------------------------------------- report

def report(tables):
    print('HC protocol - divergence between the three original declarations\n')
    for key, s in SOURCES.items():
        print('  %-6s %-34s %s' % (key, s['commit'][:12] + ' ' + s['path'].split('/')[-1], s['role']))
    print()

    print('%-12s %7s %7s %7s %7s' % ('space', 'union', 'belle', 'moana', 'c500'))
    for space in SPACES:
        print('%-12s %7d %7d %7d %7d' % (
            space, len(union_values(tables, space, SOURCES)),
            len(tables['belle'][space]), len(tables['moana'][space]), len(tables['c500'][space])))

    conflicts, agreed, device_only, app_only = [], [], [], []
    for space in ('packet_type', 'device', 'fpga'):
        for value in union_values(tables, space, CANONICAL_SOURCES):
            b = [classify(n)[1] for n in tables['belle'][space].get(value, [])]
            m = [classify(n)[1] for n in tables['moana'][space].get(value, [])]
            if b and m:
                (agreed if set(b) & set(m) else conflicts).append((space, value, b, m))
            elif b:
                device_only.append((space, value, b))
            else:
                app_only.append((space, value, m))

    print('\n-- same wire value, no shared name (%d) --' % len(conflicts))
    for space, value, b, m in conflicts:
        print('  %-12s 0x%04X  device=%-36s app=%s' % (space, value, ','.join(b), ','.join(m)))

    print('\n-- agreed by name (%d) --' % len(agreed))
    for space, value, b, m in agreed:
        print('  %-12s 0x%04X  %s' % (space, value, ','.join(sorted(set(b) & set(m)))))

    print('\n-- device declares, app has no constant (%d) --' % len(device_only))
    print('\n-- app declares, device has no constant (%d) --' % len(app_only))
    for space, value, m in app_only:
        print('  %-12s 0x%04X  %s' % (space, value, ','.join(m)))

    print('\n-- one wire value carrying several names inside a single codebase --')
    for src in SOURCES:
        for space in SPACES:
            for value, names in sorted(tables[src][space].items()):
                if len(names) > 1:
                    print('  %-6s %-12s 0x%04X  %s' % (src, space, value, ', '.join(names)))

    # 같은 이름이 코드베이스마다 다른 값을 갖는 경우 — 정본화의 진짜 위험 지점
    by_name = collections.defaultdict(dict)
    for src in SOURCES:
        for space in SPACES:
            for value, names in tables[src][space].items():
                for n in names:
                    by_name[n][src] = value
    split = {n: v for n, v in by_name.items() if len(set(v.values())) > 1}
    print('\n-- same define name, different value across codebases (%d) --' % len(split))
    for n, v in sorted(split.items()):
        print('  %-40s %s' % (n, '  '.join('%s=0x%04X' % (s, x) for s, x in sorted(v.items()))))

    return len(conflicts), len(agreed), len(device_only), len(app_only), len(split)


# --------------------------------------------------------------------------- header

PROLOGUE = '''/*
 * hc_protocol.h - canonical declaration of the HC device/client protocol.
 *
 * GENERATED by reconcile.py from the three original declarations. Do not edit by hand;
 * edit the generator. `reconcile.py --check` fails the build when this file is stale.
 *
 *   device  belle-fw       %(belle_commit)s  %(belle_path)s
 *   client  moana          %(moana_commit)s  %(moana_path)s
 *   (500C   500c-sn-fw     %(c500_commit)s  %(c500_path)s - out of scope, not merged)
 *
 * Drop-in by construction: every original spelling is kept as an alias of the canonical
 * name, so both codebases can include this header without changing a single call site.
 * 원본 이름을 지우는 것은 이 헤더가 양쪽에 들어간 뒤의 별개 작업이다.
 */
#ifndef HC_PROTOCOL_H
#define HC_PROTOCOL_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ---- transport ------------------------------------------------------------------ */
/* 장비가 서버다. 앱이 접속한다. */
#define HC_CTRL_PORT                    1234
#define HC_DATA_PORT                    1235

#define HC_HEADER_SIZE                  14
#define HC_SCAN_DATA_HEADER_SIZE        10

/* ---- header -------------------------------------------------------------------- */
/*
 * 14 bytes on the wire. Byte layout is identical in all three original declarations;
 * verify_layout.c proves it with offsetof/sizeof against the originals themselves.
 *
 * recv_id: the device declares U16, the client declares char[2]. Same bytes, different
 * model - and that divergence has already produced a latent defect. See README "recv_id".
 */
#if defined(_MSC_VER)
#  define HC_PACKED_BEGIN  __pragma(pack(push, 1))
#  define HC_PACKED_END    __pragma(pack(pop))
#  define HC_PACKED
#else
#  define HC_PACKED_BEGIN
#  define HC_PACKED_END
#  define HC_PACKED        __attribute__((packed))
#endif

HC_PACKED_BEGIN
typedef struct hc_header {
    uint8_t  identifier[2];      /* 0  'H','C' */
    uint8_t  version[2];         /* 2  product-line tag, not a protocol version */
    uint16_t recv_id;            /* 4  HC_TARGET_ID_* */
    uint16_t session_id;         /* 6  device reflects the request value */
    uint16_t packet_type;        /* 8  HC_PACKET_TYPE_* */
    uint32_t packet_body_size;   /* 10 */
} HC_PACKED hc_header_t;
HC_PACKED_END

#define HC_HEADER_MAGIC0                'H'
#define HC_HEADER_MAGIC1                'C'

/* version[2] selects the product line; both sides fix it at compile time today. */
#define HC_LINE_300C                    0x0001
#define HC_LINE_300L                    0x0002
#define HC_LINE_300MC                   0x0003
#define HC_LINE_500                     0x0100
'''

EPILOGUE = '''
#ifdef __cplusplus
}   /* extern "C" */
#endif

#endif /* HC_PROTOCOL_H */
'''

SECTION_TITLE = {
    'target_id': 'target id',
    'packet_type': 'packet_type - channel/stream class',
    'device': 'DEVICE opcodes (packet_type DEVICE_COMM / DEVICE_RESP)',
    'fpga': 'FPGA opcodes (packet_type FPGA_COMM / FPGA_RESP)',
}


def emit_header(tables):
    s = {k + '_' + f: SOURCES[k][f] for k in SOURCES for f in ('commit', 'path')}
    for k in SOURCES:
        s[k + '_commit'] = SOURCES[k]['commit'][:12]
    out = [PROLOGUE % s]

    for space in SPACES:
        out.append('\n/* ---- %s %s */\n' % (SECTION_TITLE[space],
                                             '-' * max(0, 74 - len(SECTION_TITLE[space]))))
        for value in union_values(tables, space, CANONICAL_SOURCES):
            canon = canonical_name(tables, space, value)
            origins = []
            for src in CANONICAL_SOURCES:
                for n in tables[src][space].get(value, []):
                    origins.append('%s:%s' % (src, n))
            out.append('#define %-46s 0x%04X   /* %s */\n' % (canon, value, ' '.join(origins)))

            # 원본 철자를 전부 별칭으로 남긴다 — 이래야 양쪽이 오늘 그대로 컴파일된다.
            aliases = []
            for src in CANONICAL_SOURCES:
                for n in tables[src][space].get(value, []):
                    if n != canon and n not in aliases:
                        aliases.append(n)
            for a in aliases:
                out.append('#  define %-44s %s\n' % (a, canon))

    # 500C 가 같은 값에 다른 이름을 쓰는 지점 — 병합하지 않고 기록만 한다.
    out.append('\n/* ---- 500C divergence (recorded, not merged) '
               '------------------------------------ */\n')
    for space in ('packet_type', 'device', 'fpga'):
        for value in sorted(tables['c500'][space]):
            c = [classify(n)[1] for n in tables['c500'][space][value]]
            b = [classify(n)[1] for n in tables['belle'][space].get(value, [])]
            if b and not (set(c) & set(b)):
                out.append('/* 0x%04X  %-10s 500C=%-34s belle=%s */\n'
                           % (value, space, ','.join(c), ','.join(b)))
            elif not b:
                out.append('/* 0x%04X  %-10s 500C=%-34s belle=(absent) */\n'
                           % (value, space, ','.join(c)))

    out.append(EPILOGUE)
    return ''.join(out)


def extract_struct(root, key):
    """Lift the original struct declaration verbatim, with its source line range."""
    span = STRUCT_SPAN[key]
    lines = read_source(root, key).splitlines()
    starts = [i for i, line in enumerate(lines) if re.match(span['start'], line)]
    if not starts:
        sys.exit('cannot locate the %s struct declaration' % key)
    start = starts[-1] if span.get('pick') == 'last' else starts[0]
    end = next((i for i in range(start + 1, len(lines)) if re.match(span['end'], lines[i])), None)
    if end is None:
        sys.exit('cannot locate the end of the %s struct declaration' % key)
    return '\n'.join(lines[start:end + 1]) + '\n', start + 1, end + 1


def emit_vendored(root):
    import hashlib
    out = {}
    for key in SOURCES:
        body, first, last = extract_struct(root, key)
        s = SOURCES[key]
        digest = hashlib.sha256(body.encode()).hexdigest()[:16]
        guard = 'HC_VENDORED_%s_H' % key.upper()
        text = ('/*\n'
                ' * VERBATIM excerpt - do not edit. Lifted by reconcile.py --emit-vendored.\n'
                ' *\n'
                ' *   repo   %s\n'
                ' *   commit %s (%s)\n'
                ' *   file   %s:%d-%d\n'
                ' *   sha256 %s (of the excerpt below)\n'
                ' *\n'
                ' * This is the comparison target for verify_layout.c. Copying it by hand would\n'
                ' * destroy the claim it exists to support.\n'
                ' */\n'
                '#ifndef %s\n#define %s\n\n%s\n%s\n#endif\n'
                % (s['repo'], s['commit'], s['branch'], s['path'], first, last, digest,
                   guard, guard, TYPEDEF_SHIM if STRUCT_SPAN[key]['typedefs'] else '', body))
        out[key] = text
    return out


COMPAT_PROLOGUE = '''/*
 * compat_test.c - GENERATED by reconcile.py --emit-compat. Do not edit by hand.
 *
 * For every constant the two shipping codebases declare today, assert that the ORIGINAL
 * spelling still resolves to the ORIGINAL value when hc_protocol.h is the only header
 * in scope. If this compiles, adopting the canonical header changes no call site and no
 * wire value - the merge is a rename-free, value-preserving edit.
 *
 * 이것이 "위험 없이 지금 넣을 수 있다" 의 근거다. 주장이 아니라 컴파일러가 판정한다.
 */
#include <stdio.h>
#include "include/hc_protocol.h"

'''


def emit_compat(tables):
    out = [COMPAT_PROLOGUE]
    n = 0
    for space in SPACES:
        out.append('/* ---- %s ---- */\n' % space)
        for value in union_values(tables, space, CANONICAL_SOURCES):
            for src in CANONICAL_SOURCES:
                for name in tables[src][space].get(value, []):
                    out.append('_Static_assert(%s == 0x%04X, "%s %s");\n'
                               % (name, value, src, name))
                    n += 1
    out.append('\nint main(void)\n{\n')
    out.append('    printf("OK: %d original spellings from belle-fw and moana resolve to\\n"\n' % n)
    out.append('           "    their original values through hc_protocol.h alone.\\n");\n')
    out.append('    return 0;\n}\n')
    return ''.join(out), n


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--root', default=DEFAULT_ROOT)
    ap.add_argument('--report', action='store_true')
    ap.add_argument('--emit-header', action='store_true')
    ap.add_argument('--emit-vendored', action='store_true')
    ap.add_argument('--emit-compat', action='store_true')
    ap.add_argument('--check', action='store_true')
    args = ap.parse_args()
    if not (args.report or args.emit_header or args.emit_vendored
            or args.emit_compat or args.check):
        args.report = True

    tables = load(args.root)
    target = os.path.join(HERE, 'include', 'hc_protocol.h')
    vend_dir = os.path.join(HERE, 'vendored')
    compat = os.path.join(HERE, 'compat_test.c')

    if args.report:
        report(tables)
    if args.emit_header:
        os.makedirs(os.path.dirname(target), exist_ok=True)
        with open(target, 'w') as f:
            f.write(emit_header(tables))
        print('wrote %s' % target)
    if args.emit_vendored:
        os.makedirs(vend_dir, exist_ok=True)
        for key, text in emit_vendored(args.root).items():
            path = os.path.join(vend_dir, '%s_header.h' % key)
            with open(path, 'w') as f:
                f.write(text)
            print('wrote %s' % path)
    if args.emit_compat:
        text, n = emit_compat(tables)
        with open(compat, 'w') as f:
            f.write(text)
        print('wrote %s (%d assertions)' % (compat, n))
    if args.check:
        stale = []
        want = emit_header(tables)
        have = open(target).read() if os.path.exists(target) else None
        if want != have:
            stale.append(target)
        for key, text in emit_vendored(args.root).items():
            path = os.path.join(vend_dir, '%s_header.h' % key)
            if not os.path.exists(path) or open(path).read() != text:
                stale.append(path)
        want_compat = emit_compat(tables)[0]
        if not os.path.exists(compat) or open(compat).read() != want_compat:
            stale.append(compat)
        if stale:
            sys.exit('STALE (run --emit-header --emit-vendored):\n  ' + '\n  '.join(stale))
        print('OK: generated files match the pinned originals')


if __name__ == '__main__':
    main()
