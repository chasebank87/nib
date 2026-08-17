(comment) @comment

(string) @string
(escape_sequence) @string
(interpolation) @string

(integer) @number
(float) @number

[
  (true)
  (false)
  (none)
] @keyword

[
  "and" "as" "assert" "async" "await" "break" "case" "class" "continue"
  "def" "del" "elif" "else" "except" "exec" "finally" "for" "from"
  "global" "if" "import" "in" "is" "lambda" "match" "nonlocal" "not"
  "or" "pass" "print" "raise" "return" "try" "while" "with" "yield"
  "type"
] @keyword

(function_definition
  name: (identifier) @function)

(class_definition
  name: (identifier) @type)

(call
  function: (identifier) @function)

(call
  function: (attribute
    attribute: (identifier) @function))

(decorator
  (identifier) @function)

(identifier) @variable

[
  "(" ")" "[" "]" "{" "}" "," ":" "." ";"
] @punctuation
