[unix]
cc:
    cargo build --release --bin libafl_cc
    cargo build --release --bin libafl_cxx

CC_WRAPPER := "target/release/libafl_cc"
CXX_WRAPPER := "target/release/libafl_cxx"
COVERAGE_FILE := "target/release/coverage.o"

[unix]
coverage_collector: fuzzer_lib
    clang -c -o "./target/release/coverage.o" coverage.c

[unix]
preloads:
    cargo build --release --package get_guard_num
    cargo build --release --package setup_guard_redirection

[unix]
coverage_size: preloads build_manual
    LD_PRELOAD="./target/release/libget_guard_num.so" ./llvm/build/bin/clang



[unix]
source_tarball:
    if [ ! -f llvm.zip ]; then \
        curl -L https://github.com/llvm/llvm-project/archive/refs/heads/main.zip -o llvm.zip ; \
    fi

[unix]
source: source_tarball
    if [ ! -f llvm/README.md ]; then \
        rm -rf llvm && \
        unzip -q llvm.zip && \
        mv llvm-project-main llvm ; \
    fi

[unix]
fuzzer_lib:
    LIBAFL_EDGES_MAP_ALLOCATED_SIZE=16777216 LIBAFL_EDGES_MAP_DEFAULT_SIZE=16777216 cargo build --release --target-dir target

[unix]
build_manual: source fuzzer_lib coverage_collector
    cd llvm && \
    mkdir -p build && cd build && \
    cmake -GNinja -DCMAKE_BUILD_TYPE=Release ../llvm \
    -DLLVM_ENABLE_PROJECTS="clang;lld;clang-tools-extra" \
    -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;compiler-rt" \
    -DCMAKE_C_FLAGS="-fsanitize-coverage=trace-pc-guard" \
    -DCMAKE_CXX_FLAGS="-fsanitize-coverage=trace-pc-guard" \
    -DCMAKE_EXE_LINKER_FLAGS="$(realpath ../../target/release/coverage.o)" \
    -DLLVM_ENABLE_ASSERTIONS=ON && \
    ninja clang -j $(nproc);

run_manual: build_manual preloads
    ./target/release/libafl_nautilus_fuzzer \
    --grammar-file c.fan

run_manual_no_compile_clang: fuzzer_lib preloads
    ./target/release/libafl_nautilus_fuzzer \
    --grammar-file c.fan

[unix]
build: source fuzzer_lib cc
    cd llvm && \
    mkdir -p build && cd build && \
    cmake -GNinja -DCMAKE_BUILD_TYPE=Release ../llvm \
    -DLLVM_ENABLE_PROJECTS="clang;lld;clang-tools-extra" \
    -DLLVM_ENABLE_RUNTIMES="libcxx;libcxxabi;compiler-rt" \
    -DCMAKE_C_COMPILER="$(realpath ../../target/release/libafl_cc)" \
    -DCMAKE_CXX_COMPILER="$(realpath ../../target/release/libafl_cxx)" \
    -DLLVM_ENABLE_ASSERTIONS=ON \
    -DLLVM_LIB_FUZZING_ENGINE="$(realpath ../../target/release/liblibafl_nautilus_fuzzer.a)" \
    -DLLVM_NO_DEAD_STRIP=ON \
    -DLLVM_EXPERIMENTAL_TARGETS_TO_BUILD=WebAssembly \
    -DCOMPILER_RT_INCLUDE_TESTS=OFF \
    -DCMAKE_EXE_LINKER_FLAGS="`python3-config --embed --ldflags`" && \
    ninja clang-fuzzer -j $(nproc);

[unix]
run: build
    llvm/build/bin/clang-fuzzer --grammar-file c.json --stdout-file /dev/null --stderr-file /dev/null --output out/nautilus

run_fandango:
    llvm/build/bin/clang-fuzzer --grammar-file c.fan
    # -DCMAKE_C_FLAGS="-DFUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION -fno-pie -fno-PIE" \
    # -DCMAKE_CXX_FLAGS="-DFUZZING_BUILD_MODE_UNSAFE_FOR_PRODUCTION -fno-pie -fno-PIE" \
    # -DLLVM_USE_SANITIZE_COVERAGE=ON \
    # -DLLVM_USE_LINKER=lld \
    # -DCMAKE_C_COMPILER="${CC}" \
    # -DCMAKE_CXX_COMPILER="${CXX}" \
    # -DCMAKE_C_FLAGS="${CFLAGS}" \
    # -DCMAKE_CXX_FLAGS="${CXXFLAGS}" \
    # -DLLVM_USE_SANITIZER="${LLVM_SANITIZER}" \

