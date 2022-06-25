#!/bin/sh

pip install pytest-xdist

cd /src/
pytest -n 16 ./tests/*_test.py ./tests/**/*_test.py
