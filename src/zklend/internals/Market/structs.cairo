// SPDX-License-Identifier: BUSL-1.1

namespace Structs {
    struct ReserveData {
        enabled: felt,
        decimals: felt,
        z_token_address: felt,
        interest_rate_model: felt,
        collateral_factor: felt,
        borrow_factor: felt,
        reserve_factor: felt,
        last_update_timestamp: felt,
        lending_accumulator: felt,
        debt_accumulator: felt,
        current_lending_rate: felt,
        current_borrowing_rate: felt,
        raw_total_debt: felt,
        flash_loan_fee: felt,
        liquidation_bonus: felt,
        debt_limit: felt,
    }
}
