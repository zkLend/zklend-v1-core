// SPDX-License-Identifier: BUSL-1.1

%lang starknet

@event
func NewReserve(
    token: felt,
    z_token: felt,
    decimals: felt,
    interest_rate_model: felt,
    collateral_factor: felt,
    borrow_factor: felt,
    reserve_factor: felt,
    flash_loan_fee: felt,
    liquidation_bonus: felt,
) {
}

@event
func TreasuryUpdate(new_treasury: felt) {
}

@event
func AccumulatorsSync(token: felt, lending_accumulator: felt, debt_accumulator: felt) {
}

@event
func InterestRatesSync(token: felt, lending_rate: felt, borrowing_rate: felt) {
}

@event
func Deposit(user: felt, token: felt, face_amount: felt) {
}

@event
func Withdrawal(user: felt, token: felt, face_amount: felt) {
}

@event
func Borrowing(user: felt, token: felt, raw_amount: felt, face_amount: felt) {
}

@event
func Repayment(user: felt, token: felt, raw_amount: felt, face_amount: felt) {
}

@event
func Liquidation(
    liquidator: felt,
    user: felt,
    debt_token: felt,
    debt_amount: felt,
    collateral_token: felt,
    collateral_amount: felt,
) {
}

// NOTE: `fee` indicates the actual fee paid back, which could be higher than the minimum required.
@event
func FlashLoan(receiver: felt, token: felt, amount: felt, fee: felt) {
}

@event
func CollateralEnabled(user: felt, token: felt) {
}

@event
func CollateralDisabled(user: felt, token: felt) {
}
