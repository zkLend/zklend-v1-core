def string_to_felt(string: str) -> int:
    return int.from_bytes(
        list(bytes(string, encoding="ascii")), byteorder="big", signed=False
    )
