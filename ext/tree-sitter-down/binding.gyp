{
  "targets": [
    {
      "target_name": "tree_sitter_down_binding",
      "dependencies": [
        "<!(node -e \"require('node-addon-api').targets\"):node-addon-api"
      ],
      "include_dirs": [
        "src",
      ],
      "sources": [
        "bindings/node.cc",
        "src/parser.c",
        "src/scanner.c",
      ],
      "cflags_c": [
        "-std=c11",
      ],
    }
  ]
}
