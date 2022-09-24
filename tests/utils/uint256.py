from typing import Tuple


class ValueOutOfRangeException(Exception):
    value: int

    def __init__(self, value: int):
        self.value = value
        super().__init__(f"value out of range: {value}")


class Uint256:
    low: int
    high: int

    def __init__(self, low: int, high: int):
        self.low = low
        self.high = high

    def __iter__(self):
        return Uint256Iter(self)

    def __eq__(self, other):
        if other is int:
            return self.to_int() == other
        else:
            return self.low == other.low and self.high == other.high

    def __repr__(self) -> str:
        return self.__str__()

    def __str__(self) -> str:
        return f"Uint256(low={self.low}, high={self.high})"

    def to_int(self) -> int:
        return self.high << 128 | self.low

    def to_tuple(self) -> Tuple[int, int]:
        return (self.low, self.high)

    @staticmethod
    def from_int(value):
        if value < 0 or value > (1 << 256):
            raise ValueOutOfRangeException(value)
        return Uint256(value & ((1 << 128) - 1), value >> 128)


class Uint256Iter:
    inner: Uint256
    count_taken: int

    def __init__(self, inner: Uint256):
        self.inner = inner
        self.count_taken = 0

    def __next__(self):
        if self.count_taken == 0:
            self.count_taken += 1
            return self.inner.low
        elif self.count_taken == 1:
            self.count_taken += 1
            return self.inner.high
        else:
            raise StopIteration
