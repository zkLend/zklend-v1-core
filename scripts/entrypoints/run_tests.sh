#!/bin/sh

pip install pytest-xdist

cd /work/
pytest -n 16 -v ./tests/*_test.py ./tests/**/*_test.py
