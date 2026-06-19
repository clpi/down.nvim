; ── Headings ──────────────────────────────────────────────────
(heading
  (atx_marker) @markup.heading.marker)

(heading
  (atx_marker) @_marker
  (#match? @_marker "^# ")
  ) @markup.heading.1

(heading
  (atx_marker) @_marker
  (#match? @_marker "^## ")
  ) @markup.heading.2

(heading
  (atx_marker) @_marker
  (#match? @_marker "^### ")
  ) @markup.heading.3

(heading
  (atx_marker) @_marker
  (#match? @_marker "^#### ")
  ) @markup.heading.4

(heading
  (atx_marker) @_marker
  (#match? @_marker "^##### ")
  ) @markup.heading.5

(heading
  (atx_marker) @_marker
  (#match? @_marker "^###### ")
  ) @markup.heading.6

; ── Tags ──────────────────────────────────────────────────────
(tag) @label

; ── Wiki links ────────────────────────────────────────────────
(wiki_link
  "[[" @markup.link
  "]]" @markup.link)
(wiki_link
  target: (_) @markup.link.label)

; ── Embeds ────────────────────────────────────────────────────
(embed
  "![" @markup.link
  "]]" @markup.link)
(embed
  target: (_) @markup.link.url)

; ── Task markers ──────────────────────────────────────────────
(task_marker) @keyword

; ── Bold / Italic / Strikethrough ────────────────────────────
(bold) @markup.strong
(italic) @markup.italic
(strikethrough) @markup.strikethrough

; ── Code ──────────────────────────────────────────────────────
(inline_code) @markup.raw
(fenced_code_block) @markup.raw.block
(indented_code_block) @markup.raw.block

; ── Links & Images ────────────────────────────────────────────
(link
  "[" @markup.link
  "]" @markup.link
  "(" @markup.link
  ")" @markup.link)
(link
  url: (_) @markup.link.url)

(image
  "![" @markup.link
  "]" @markup.link
  "(" @markup.link
  ")" @markup.link)
(image
  url: (_) @markup.link.url)

(autolink
  "<" @markup.link
  ">" @markup.link)

; ── Block elements ────────────────────────────────────────────
(thematic_break) @punctuation.special
(block_quote) @markup.quote

; ── Lists ─────────────────────────────────────────────────────
(list_marker) @markup.list

; ── Comments ──────────────────────────────────────────────────
(line_comment) @comment.line
(block_comment) @comment.block

; ── Front matter ──────────────────────────────────────────────
(frontmatter) @keyword.directive
