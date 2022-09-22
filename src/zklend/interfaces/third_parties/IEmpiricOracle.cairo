%lang starknet

// IEmpiricOracle

@contract_interface
namespace IEmpiricOracle {
    func get_value(key: felt, aggregation_mode: felt) -> (
        value: felt, decimals: felt, last_updated_timestamp: felt, num_sources_aggregated: felt
    ) {
    }
}
