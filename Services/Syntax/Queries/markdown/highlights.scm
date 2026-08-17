(atx_heading
  (inline) @heading)

(setext_heading
  (paragraph) @heading)

[
  (atx_h1_marker)
  (atx_h2_marker)
  (atx_h3_marker)
  (atx_h4_marker)
  (atx_h5_marker)
  (atx_h6_marker)
] @punctuation

(fenced_code_block) @string
(indented_code_block) @string

(link_destination) @link
(link_title) @string

(code_span) @string

[
  (list_marker_plus)
  (list_marker_minus)
  (list_marker_star)
  (list_marker_dot)
  (list_marker_parenthesis)
] @punctuation
