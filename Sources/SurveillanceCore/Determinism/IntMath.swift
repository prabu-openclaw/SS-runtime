/// Integer helpers for authoritative simulation. No IEEE floating comparison.
public enum IntMath {
    public static func abs(_ value: Int64) -> Int64 {
        value < 0 ? 0 &- value : value
    }

    public static func gcd(_ a: Int64, _ b: Int64) -> Int64 {
        var x = abs(a)
        var y = abs(b)
        while y != 0 {
            let t = x % y
            x = y
            y = t
        }
        return x
    }

    /// Integer square root, flooring.
    public static func isqrt(_ n: Int64) -> Int64 {
        precondition(n >= 0)
        if n < 2 { return n }
        var x0 = n
        var x1 = (x0 + n / x0) / 2
        while x1 < x0 {
            x0 = x1
            x1 = (x0 + n / x0) / 2
        }
        return x0
    }

    /// `n / d` rounded half away from zero.
    public static func divHalfAway(_ n: Int64, _ d: Int64) -> Int64 {
        precondition(d != 0)
        let negative = (n < 0) != (d < 0)
        let an = abs(n)
        let ad = abs(d)
        let q = an / ad
        let r = an % ad
        let rounded = r * 2 >= ad ? q + 1 : q
        return negative ? 0 &- rounded : rounded
    }

    /// `(a * b) / d` rounded half away from zero using a 128-bit intermediate.
    public static func mulDivHalfAway(_ a: Int64, _ b: Int64, _ d: Int64) -> Int64 {
        precondition(d != 0)
        let sign: Int64 = ((a < 0) != (b < 0)) != (d < 0) ? -1 : 1
        let ua = UInt64(abs(a))
        let ub = UInt64(abs(b))
        let ud = UInt64(abs(d))
        let full = ua.multipliedFullWidth(by: ub)
        let (quotient, remainder) = ud.dividingFullWidth(full)
        let rounded = remainder * 2 >= ud ? quotient + 1 : quotient
        let asSigned = Int64(bitPattern: rounded)
        return sign < 0 ? 0 &- asSigned : asSigned
    }
}
