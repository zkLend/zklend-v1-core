#!/bin/sh

cd /src/
pytest ./tests/*_test.py ./tests/**/*_test.py
