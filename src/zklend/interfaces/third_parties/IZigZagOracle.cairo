%lang starknet

# IZigZagOracle

# Interface taken from:
#   https://github.com/ZigZagExchange/starknet-oracle/blob/3a6ee6c51cd490be36066adc4a3f9ee85d9d7887/readme.md

from starkware.cairo.common.uint256 import Uint256

struct Response:
    member roundId : felt  # self-explanatory
    member identifier : felt  # example ETH/USD (identified by hash or index)
    member answer : Uint256  # price reurned by request
    member timestamp : felt  # timestamp when request was received
    member block_number : felt  # block_number when request was received
    member transmitter : felt  # address of where the data is coming from (will be useful later)
end

@contract_interface
namespace IZigZagOracle:
    # returned prices are multiplied by 10^decimals
    func decimals() -> (decimals):
    end

    # Returns the timestamp of when prices where last updated
    func latest_timestamp() -> (ts : felt):
    end

    # Returns the round ID of when prices where last updated
    func latest_round() -> (roundId : felt):
    end

    # returns a Uint256 price
    func latest_price() -> (price : felt):
    end

    # returns the latest Response data (see below)
    func latest_round_data() -> (res : Response):
    end

    # takes a round ID and returns the Response data at round round ID
    func get_round_data(roundId : felt) -> (res : Response):
    end

    # returns the latest transmission details
    func latestTransmissionDetails() -> (
        config_digest, epoch, round, latest_answer, latest_timestamp
    ):
    end
end
