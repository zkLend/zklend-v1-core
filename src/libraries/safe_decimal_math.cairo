use super::{pow, safe_math};

// These two consts MUST be the same.
const SCALE: felt252 = 1000000000000000000000000000;
const SCALE_U256: u256 = 1000000000000000000000000000;

/// This function assumes `b` is scaled by `SCALE`
fn mul(a: felt252, b: felt252) -> felt252 {
    let scaled_product = safe_math::mul(a, b);
    safe_math::div(scaled_product, SCALE)
}

/// This function assumes `b` is scaled by `SCALE`
fn div(a: felt252, b: felt252) -> felt252 {
    let scaled_a = safe_math::mul(a, SCALE);
    safe_math::div(scaled_a, b)
}

/// This function assumes `b` is scaled by `10 ^ b_decimals`
fn mul_decimals(a: felt252, b: felt252, b_decimals: felt252) -> felt252 {
    // `ten_pow` already handles overflow anyways
    let scale = pow::ten_pow(b_decimals);

    let scaled_product = safe_math::mul(a, b);
    safe_math::div(scaled_product, scale)
}

/// This function assumes `b` is scaled by `10 ^ b_decimals`
fn div_decimals(a: felt252, b: felt252, b_decimals: felt252) -> felt252 {
    // `ten_pow` already handles overflow anyways
    let scale = pow::ten_pow(b_decimals);

    let scaled_a = safe_math::mul(a, scale);
    safe_math::div(scaled_a, b)
}

#[cfg(test)]
mod tests {
    use test::test_utils::assert_eq;

    #[test]
    fn test_mul() {
        assert_eq(@super::mul(10, 2000000000000000000000000000), @20, 'FAILED');
    }

    #[test]
    fn test_mul_decimals() {
        assert_eq(@super::mul_decimals(10, 2000000000000000000000000000, 27), @20, 'FAILED');
    }

    #[test]
    #[should_panic(expected: ('SM_MUL_OF', ))]
    fn test_mul_overflow() {
        super::mul(
            0x400000000000000000000000000000000000000000000000000000000000000,
            2000000000000000000000000000
        );
    }

    #[test]
    #[should_panic(expected: ('SM_MUL_OF', ))]
    fn test_mul_decimals_overflow() {
        super::mul_decimals(
            0x400000000000000000000000000000000000000000000000000000000000000,
            2000000000000000000000000000,
            27
        );
    }

    #[test]
    fn test_div() {
        assert_eq(@super::div(10, 2000000000000000000000000000), @5, 'FAILED');
    }

    #[test]
    fn test_div_decimals() {
        assert_eq(@super::div_decimals(10, 2000000000000000000000000000, 27), @5, 'FAILED');
    }
}
