#include "tree_sitter/parser.h"
#include <wctype.h>

enum TokenType {
  LINE_ENDING,
  EOF,
};

void *tree_sitter_down_external_scanner_create(void) { return NULL; }

void tree_sitter_down_external_scanner_destroy(void *payload) {
  (void)payload;
}

unsigned tree_sitter_down_external_scanner_serialize(void *payload,
                                                     char *buffer) {
  (void)payload;
  (void)buffer;
  return 0;
}

void tree_sitter_down_external_scanner_deserialize(void *payload,
                                                   const char *buffer,
                                                   unsigned length) {
  (void)payload;
  (void)buffer;
  (void)length;
}

bool tree_sitter_down_external_scanner_scan(void *payload, TSLexer *lexer,
                                            const bool *valid_symbols) {
  (void)payload;

  if (valid_symbols[LINE_ENDING] && (lexer->lookahead == '\n' || lexer->lookahead == '\r')) {
    lexer->result_symbol = LINE_ENDING;
    if (lexer->lookahead == '\r') {
      lexer->advance(lexer, false);
      if (lexer->lookahead == '\n') {
        lexer->advance(lexer, false);
      }
    } else {
      lexer->advance(lexer, false);
    }
    return true;
  }

  if (valid_symbols[EOF] && lexer->lookahead == '\0') {
    lexer->result_symbol = EOF;
    return true;
  }

  return false;
}
