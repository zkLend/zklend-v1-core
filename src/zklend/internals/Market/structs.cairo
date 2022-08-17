# SPDX-License-Identifier: BUSL-1.1

namespace Structs:
    struct ReserveData:
        member enabled : felt
        member decimals : felt
        member z_token_address : felt
        member interest_rate_model : felt
        member collateral_factor : felt
        member borrow_factor : felt
        member reserve_factor : felt
        member last_update_timestamp : felt
        member lending_accumulator : felt
        member debt_accumulator : felt
        member current_lending_rate : felt
        member current_borrowing_rate : felt
        member raw_total_debt : felt
        member flash_loan_fee : felt
        member liquidation_bonus : felt
    end
end
