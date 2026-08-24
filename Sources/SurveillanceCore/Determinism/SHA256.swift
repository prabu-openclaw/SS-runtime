import Foundation

/// SHA-256 producing lowercase hex digests for canonical state hashing.
public enum SHA256 {
    public static func hash(_ data: [UInt8]) -> [UInt8] {
        data.withUnsafeBytes { hash(bytes: $0, count: data.count) }
    }

    public static func hash(_ data: Data) -> [UInt8] {
        data.withUnsafeBytes { hash(bytes: $0, count: data.count) }
    }

    public static func hex(_ data: [UInt8]) -> String {
        digestHex(hash(data))
    }

    public static func hex(_ data: Data) -> String {
        digestHex(hash(data))
    }

    public static func hex(_ string: String) -> String {
        hex(Array(string.utf8))
    }

    public static let emptyDigest = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

    private static func digestHex(_ digest: [UInt8]) -> String {
        digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func hash(bytes: UnsafeRawBufferPointer, count: Int) -> [UInt8] {
        var h: [UInt32] = [
            0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
            0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19
        ]
        let k: [UInt32] = [
            0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
            0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
            0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
            0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
            0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
            0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
            0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
            0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2
        ]
        var w = [UInt32](repeating: 0, count: 64)

        func compress(_ block: UnsafeRawBufferPointer) {
            for i in 0..<16 {
                let o = i * 4
                w[i] = (UInt32(block[o]) << 24)
                    | (UInt32(block[o + 1]) << 16)
                    | (UInt32(block[o + 2]) << 8)
                    | UInt32(block[o + 3])
            }
            for i in 16..<64 {
                let s0 = rotateRight(w[i - 15], 7) ^ rotateRight(w[i - 15], 18) ^ (w[i - 15] >> 3)
                let s1 = rotateRight(w[i - 2], 17) ^ rotateRight(w[i - 2], 19) ^ (w[i - 2] >> 10)
                w[i] = w[i - 16] &+ s0 &+ w[i - 7] &+ s1
            }

            var a = h[0], b = h[1], c = h[2], d = h[3]
            var e = h[4], f = h[5], g = h[6], hh = h[7]
            for i in 0..<64 {
                let s1 = rotateRight(e, 6) ^ rotateRight(e, 11) ^ rotateRight(e, 25)
                let ch = (e & f) ^ (~e & g)
                let temp1 = hh &+ s1 &+ ch &+ k[i] &+ w[i]
                let s0 = rotateRight(a, 2) ^ rotateRight(a, 13) ^ rotateRight(a, 22)
                let maj = (a & b) ^ (a & c) ^ (b & c)
                let temp2 = s0 &+ maj
                hh = g
                g = f
                f = e
                e = d &+ temp1
                d = c
                c = b
                b = a
                a = temp1 &+ temp2
            }
            h[0] &+= a; h[1] &+= b; h[2] &+= c; h[3] &+= d
            h[4] &+= e; h[5] &+= f; h[6] &+= g; h[7] &+= hh
        }

        let bitCount = UInt64(count) * 8
        var offset = 0
        if let base = bytes.baseAddress {
            while offset + 64 <= count {
                compress(UnsafeRawBufferPointer(start: base + offset, count: 64))
                offset += 64
            }
        }

        var tail = [UInt8](repeating: 0, count: 128)
        let rem = count - offset
        if rem > 0, let base = bytes.baseAddress {
            for i in 0..<rem {
                tail[i] = base.load(fromByteOffset: offset + i, as: UInt8.self)
            }
        }
        tail[rem] = 0x80
        var padded = rem + 1
        while padded % 64 != 56 {
            padded += 1
        }
        for (index, shift) in [56, 48, 40, 32, 24, 16, 8, 0].enumerated() {
            tail[padded + index] = UInt8((bitCount >> shift) & 0xff)
        }
        let tailCount = padded + 8
        tail.withUnsafeBytes { raw in
            var block = 0
            while block < tailCount {
                compress(UnsafeRawBufferPointer(start: raw.baseAddress! + block, count: 64))
                block += 64
            }
        }

        var digest: [UInt8] = []
        digest.reserveCapacity(32)
        for word in h {
            digest.append(UInt8((word >> 24) & 0xff))
            digest.append(UInt8((word >> 16) & 0xff))
            digest.append(UInt8((word >> 8) & 0xff))
            digest.append(UInt8(word & 0xff))
        }
        return digest
    }

    private static func rotateRight(_ value: UInt32, _ bits: UInt32) -> UInt32 {
        (value >> bits) | (value << (32 - bits))
    }
}
