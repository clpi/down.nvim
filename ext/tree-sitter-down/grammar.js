/**
 * @file tree-sitter-down grammar
 *
 * `down` is a markdown superset for developer-focused note-taking.
 * It extends CommonMark with:
 *   - YAML front matter (`---` fences)
 *   - `@tag` and `#tag` annotations
 *   - `~~todo~~` task markers
 *   - `[[wiki links]]`
 *   - `![[embeds]]`
 *   - Line comments: `--`
 *   - Block comments: `-/ ... /-` and `--! ... !--`
 */

const PREC = {
  comment: 1,
  tag: 2,
  wikilink: 3,
  embed: 4,
  task: 5,
};

module.exports = grammar({
  name: "down",

  extras: ($) => [/[\t ]/],

  externals: ($) => [
    $._line_ending,
    $._eof,
  ],

  conflicts: ($) => [
    [$.paragraph],
  ],

  rules: {
    document: ($) =>
      seq(
        optional($.frontmatter),
        repeat(choice($.block_element, $.blank_line)),
      ),

    // ── Front matter ──────────────────────────────────────────
    frontmatter: ($) =>
      seq(
        "---",
        repeat1(seq(optional(/./), $._line_ending)),
        "---",
        $._line_ending,
      ),

    // ── Block elements ────────────────────────────────────────
    block_element: ($) =>
      choice(
        $.heading,
        $.thematic_break,
        $.block_quote,
        $.list,
        $.fenced_code_block,
        $.indented_code_block,
        $.paragraph,
        $.block_comment,
        $.line_comment,
      ),

    blank_line: ($) => /\r?\n/,

    // ── Headings ──────────────────────────────────────────────
    heading: ($) =>
      seq(
        $.atx_marker,
        repeat1(choice($.inline_element, /[^\n\r]+/)),
        $._line_ending,
      ),

    atx_marker: ($) => field("level", /[#{1,6}][\t ]+/),

    // ── Thematic break ────────────────────────────────────────
    thematic_break: ($) =>
      prec.right(
        seq(
          choice(
            repeat1("*"),
            repeat1("-"),
            repeat1("_"),
          ),
          $._line_ending,
        ),
      ),

    // ── Block quote ───────────────────────────────────────────
    block_quote: ($) =>
      prec.right(
        seq(
          ">",
          optional($._space),
          repeat1(choice($.block_element, $.blank_line)),
        ),
      ),

    _space: ($) => /[\t ]+/,

    // ── Lists ─────────────────────────────────────────────────
    list: ($) =>
      prec.right(
        seq(
          $.list_marker,
          repeat1(choice($.list_item, $.blank_line)),
        ),
      ),

    list_marker: ($) =>
      choice(
        /[-*+][\t ]+/,
        /\d+\.[\t ]+/,
      ),

    list_item: ($) =>
      prec.right(
        seq(
          repeat1(choice($.inline_element, /[^\n\r]+/)),
          $._line_ending,
        ),
      ),

    // ── Fenced code block ─────────────────────────────────────
    fenced_code_block: ($) =>
      seq(
        "`" * 3,
        optional(field("info_string", /[^\n\r]*/)),
        $._line_ending,
        repeat(seq(optional(/./), $._line_ending)),
        "`" * 3,
        optional($._line_ending),
      ),

    // ── Indented code block ───────────────────────────────────
    indented_code_block: ($) =>
      prec.right(
        seq(
          /[\t ]{4}/,
          repeat1(seq(optional(/./), $._line_ending)),
        ),
      ),

    // ── Paragraph ─────────────────────────────────────────────
    paragraph: ($) =>
      prec.right(
        seq(
          repeat1(choice($.inline_element, /[^\n\r]+/)),
          $._line_ending,
        ),
      ),

    // ── Inline elements ───────────────────────────────────────
    inline_element: ($) =>
      choice(
        $.line_comment,
        $.tag,
        $.wiki_link,
        $.embed,
        $.bold,
        $.italic,
        $.strikethrough,
        $.task_marker,
        $.inline_code,
        $.link,
        $.image,
        $.autolink,
      ),

    // ── Tags: @tag and #tag ───────────────────────────────────
    tag: ($) =>
      prec(PREC.tag,
        seq(
          choice("@", "#"),
          /[a-zA-Z_][a-zA-Z0-9_./-]*/,
        ),
      ),

    // ── Wiki links: [[target]] and [[target|display]] ─────────
    wiki_link: ($) =>
      prec(PREC.wikilink,
        seq(
          "[[",
          field("target", /[^\]\|]+/),
          optional(seq("|", field("display", /[^\]]+/))),
          "]]",
        ),
      ),

    // ── Embeds: ![[file]] and ![[file|alias]] ─────────────────
    embed: ($) =>
      prec(PREC.embed,
        seq(
          "![",
          "[",
          field("target", /[^\]\|]+/),
          optional(seq("|", field("display", /[^\]]+/))),
          "]]",
        ),
      ),

    // ── Task markers: ~~~todo~~ / ~~done~~ ────────────────────
    task_marker: ($) =>
      prec(PREC.task,
        seq(
          "~~",
          choice("todo", "done", "doing", "waiting", "cancelled", "blocked"),
          "~~",
        ),
      ),

    // ── Bold **text** ─────────────────────────────────────────
    bold: ($) =>
      seq("**", repeat1(choice(/[^*]+/, /\*[^*]/)), "**"),

    // ── Italic *text* ─────────────────────────────────────────
    italic: ($) =>
      seq("*", repeat1(choice(/[^*]+/)), "*"),

    // ── Strikethrough ~~text~~ ────────────────────────────────
    strikethrough: ($) =>
      seq("~~", repeat1(choice(/[^~]+/)), "~~"),

    // ── Inline code `code` ────────────────────────────────────
    inline_code: ($) =>
      seq("`", repeat1(choice(/[^`]+/)), "`"),

    // ── Links [text](url) ─────────────────────────────────────
    link: ($) =>
      seq(
        "[",
        repeat1(choice(/[^ \]\[]+/, $._space)),
        "]",
        "(",
        field("url", /[^)]+/),
        ")",
      ),

    // ── Images ![alt](url) ────────────────────────────────────
    image: ($) =>
      seq(
        "![",
        repeat1(choice(/[^ \]\[]+/, $._space)),
        "]",
        "(",
        field("url", /[^)]+/),
        ")",
      ),

    // ── Autolinks <url> ───────────────────────────────────────
    autolink: ($) =>
      seq("<", /[^>]+/, ">"),

    // ── Comments ──────────────────────────────────────────────
    line_comment: ($) =>
      prec(PREC.comment,
        seq("--", /[^\n\r]*/),
      ),

    block_comment: ($) =>
      prec(PREC.comment,
        choice(
          seq("-/", repeat(choice(/./, $._line_ending)), "/-"),
          seq("--!", repeat(choice(/./, $._line_ending)), "!--"),
        ),
      ),
  },
});
