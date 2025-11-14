OUT_DIR=fandango-seeded-havoc
CORES="3"
export PYTHONPATH=$(echo .venv/lib/python*/site-packages)
rm -rf out/$OUT_DIR
llvm/build/bin/clang-fuzzer \
    --grammar-file c.fan \
    --output "out/$OUT_DIR" \
    --stdout-file /dev/null \
    --stderr-file /dev/null \
    --cores $CORES \
    --broker-port "133$CORES"