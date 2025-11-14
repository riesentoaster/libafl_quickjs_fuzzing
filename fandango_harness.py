from typing import Any
from fandango import Fandango


class FandangoWrapper:
    def __init__(self, fan_file: str, kwargs: dict[str, Any]):
        with open(fan_file) as f:
            self.fan = Fandango(f, **kwargs)
        self.generator = self.fan.generate_solutions()


def setup(fan_file: str, kwargs: dict[str, Any]) -> FandangoWrapper:
    return FandangoWrapper(fan_file, kwargs)


def next_input(wrapper: FandangoWrapper) -> bytes:
    return bytes(next(wrapper.generator))


def parse_input(wrapper: FandangoWrapper, input: bytes) -> int:
    return len(list(wrapper.fan.parse(input)))
