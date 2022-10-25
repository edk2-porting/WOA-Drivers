#!/bin/bash
find ./components -type f '!' -name '*.inf_' | xargs sha256sum | sort > hash.txt