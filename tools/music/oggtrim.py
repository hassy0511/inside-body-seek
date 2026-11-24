"""Cut an Ogg Vorbis stream to an exact number of samples, packet-wise.

Why: a Vorbis encoder does not know what comes after the last sample, so it
extrapolates and the last block carries extra error.  For a loop that error
sits right at the loop point (measured: the decoded OGGs of bgm_clinic and
bgm_spark clicked at the seam, the WAVs did not).  The fix is to encode the
loop followed by its own first few thousand samples (so the encoder sees the
real continuation), then remove the packets that only carry the extra
samples, and set the last page's granule position to the loop length.

Decoders trim the end of the last packet to the last granule position
(libvorbis does this in vorbis_synthesis_blockin, but only inside the output
of that last packet; that is why the extra packets are removed rather than
only rewriting the granule position).
"""
from __future__ import annotations

import struct


def _crc_table():
    t = []
    for i in range(256):
        r = i << 24
        for _ in range(8):
            r = ((r << 1) ^ 0x04C11DB7) if r & 0x80000000 else (r << 1)
            r &= 0xFFFFFFFF
        t.append(r)
    return t


_CRC = _crc_table()


def ogg_crc(data: bytes) -> int:
    c = 0
    for b in data:
        c = ((c << 8) & 0xFFFFFFFF) ^ _CRC[((c >> 24) & 0xFF) ^ b]
    return c


class Page:
    def __init__(self, raw: bytes):
        assert raw[:4] == b"OggS", "not an Ogg page"
        self.flags = raw[5]
        self.granule = struct.unpack_from("<q", raw, 6)[0]
        self.serial, self.seq = struct.unpack_from("<II", raw, 14)
        n = raw[26]
        self.lacing = list(raw[27:27 + n])
        self.body = raw[27 + n:27 + n + sum(self.lacing)]
        self.size = 27 + n + sum(self.lacing)

    def to_bytes(self) -> bytes:
        head = bytearray(b"OggS" + bytes([0, self.flags]) + struct.pack("<q", self.granule)
                         + struct.pack("<III", self.serial, self.seq, 0) + bytes([len(self.lacing)])
                         + bytes(self.lacing))
        raw = bytes(head) + self.body
        crc = ogg_crc(raw)
        return raw[:22] + struct.pack("<I", crc) + raw[26:]


def read_pages(data: bytes) -> list[Page]:
    out, i = [], 0
    while i < len(data):
        p = Page(data[i:])
        out.append(p)
        i += p.size
    return out


def _packets(pages):
    """(page index, segment index of the packet's last segment, packet bytes)."""
    out, cur = [], b""
    for pi, p in enumerate(pages):
        pos = 0
        for si, lv in enumerate(p.lacing):
            cur += p.body[pos:pos + lv]
            pos += lv
            if lv < 255:
                out.append((pi, si, cur))
                cur = b""
    return out


def trim(data: bytes, total: int) -> bytes:
    """Keep the first `total` samples of a single-stream Ogg Vorbis file.

    Raises ValueError when the stream does not look like plain libvorbis
    output (two modes: short and long block), so the caller can fall back."""
    pages = read_pages(data)
    pk = _packets(pages)
    ident = pk[0][2]
    if ident[:7] != b"\x01vorbis":
        raise ValueError("not a Vorbis stream")
    bs = [1 << (ident[28] & 0x0F), 1 << (ident[28] >> 4)]
    audio = pk[3:]
    # sample count per packet (libvorbis: the first audio packet returns nothing;
    # then each returns a quarter of the previous block plus a quarter of this one)
    gran = []
    g, prev = 0, None
    for _, _, b in audio:
        if not b or b[0] & 1:
            raise ValueError("unexpected packet")
        w = bs[(b[0] >> 1) & 1]     # mode bit: libvorbis writes mode 0 = short, 1 = long
        if prev is not None:
            g += prev // 4 + w // 4
        prev = w
        gran.append(g)
    # verify against every page's granule position (the encoder's own count)
    for k, (pi, si, _) in enumerate(audio):
        p = pages[pi]
        last_of_page = si == max(i for i, lv in enumerate(p.lacing) if lv < 255)
        if last_of_page and not (p.flags & 4) and p.granule != gran[k]:
            raise ValueError(f"granule mismatch on page {pi}: {p.granule} vs {gran[k]}")
    final = pages[-1].granule
    if not (gran[-1] >= final > (gran[-2] if len(gran) > 1 else 0)):
        raise ValueError("final granule does not fit the packets")
    if total > final:
        raise ValueError("the stream is shorter than the cut")
    keep = next(k for k, gk in enumerate(gran) if gk >= total)
    if keep == 0 or gran[keep - 1] >= total:
        raise ValueError("no packet ends after the cut")
    pi, si, _ = audio[keep]
    pages = pages[:pi + 1]
    last = pages[pi]
    nbytes = sum(last.lacing[:si + 1])
    last.lacing = last.lacing[:si + 1]
    last.body = last.body[:nbytes]
    last.granule = total
    last.flags |= 4                 # end of stream
    return b"".join(p.to_bytes() for p in pages)
