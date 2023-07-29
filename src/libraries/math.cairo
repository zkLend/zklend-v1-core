use integer::u256_overflow_mul;
use option::OptionTrait;
use traits::{Into, TryInto};

use super::{pow, safe_math};

/// Computes the logical left shift of `felt252`, with result in the range of [0, 2 ^ 251).
fn shl(a: felt252, b: felt252) -> felt252 {
    // For left shifting we pretend there're only 251 bits in `felt252`.
    if Into::<_, u256>::into(b) <= 250 {
        let shift = pow::two_pow(b);
        let shift: u256 = shift.into();
        let a: u256 = a.into();

        let (product, _) = u256_overflow_mul(a, shift);

        // Takes all 128 bits from low, and 123 bits from high
        let trimmed_high = product.high & 0x7ffffffffffffffffffffffffffffff;

        let res = (u256 { low: product.low, high: trimmed_high });

        // Safe to unwrap as this number always fits in `felt252`
        res.try_into().unwrap()
    } else {
        0
    }
}

// Computes the logical right shift of a field element
fn shr(a: felt252, b: felt252) -> felt252 {
    if Into::<_, u256>::into(b) <= 251 {
        let denominator = pow::two_pow(b);
        safe_math::div(a, denominator)
    } else {
        0
    }
}

#[cfg(test)]
mod tests {
    use test::test_utils::assert_eq;

    #[test]
    fn test_shl() {
        assert_eq(@super::shl(0, 100), @0, 'FAILED');
        assert_eq(@super::shl(0x2, 1), @0x4, 'FAILED');
        assert_eq(@super::shl(0x4010000000001, 45), @0x802000000000200000000000, 'FAILED');
        assert_eq(
            @super::shl(0x800000000000000000000000000000000000000000000000000000000000000, 0),
            @0x0,
            'FAILED'
        );
        assert_eq(
            @super::shl(0x4010000000001, 210),
            @0x400000000040000000000000000000000000000000000000000000000000000,
            'FAILED'
        );
    }

    #[test]
    fn test_shr() {
        assert_eq(@super::shr(0x0, 100), @0x0, 'FAILED');
        assert_eq(@super::shr(0x2, 1), @0x1, 'FAILED');
        assert_eq(@super::shr(0x4010000000001, 45), @0x20, 'FAILED');
        assert_eq(
            @super::shr(0x800000000000011000000000000000000000000000000000000000000000000, 100),
            @0x80000000000001100000000000000000000000,
            'FAILED'
        );
        assert_eq(
            @super::shr(0x800000000000011000000000000000000000000000000000000000000000000, 251),
            @0x1,
            'FAILED'
        );
        assert_eq(
            @super::shr(0x800000000000011000000000000000000000000000000000000000000000000, 252),
            @0x0,
            'FAILED'
        );
    }
}
