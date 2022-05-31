%lang starknet

# IPontisOracle

@contract_interface
namespace IPontisOracle:
    func get_decimals(key : felt) -> (decimals : felt):
    end

    func get_value(key : felt, aggregation_mode : felt) -> (
        value : felt, last_updated_timestamp : felt
    ):
    end
end
