; Inject languages into fenced code blocks based on the info string.
; NOTE: This requires the host editor to support `#set-lang-from-info-string!`
; or equivalent. The generic fallback is included below.

(frontmatter) @injection.content
 (#set! injection.language "yaml")
 (#set! injection.include-children)
