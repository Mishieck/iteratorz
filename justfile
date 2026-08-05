run-examples:
  for exe in examples/*; do zig build "example_$(basename -s '.zig' $exe)"; done
