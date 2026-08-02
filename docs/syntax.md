# awkward syntax

```ebnf
<program> ::= <statement>*
<statement> ::= <variable_declaration> | <if_statement> | <while_statement> | <for_statement> | <function_declaration> | <struct_declaration> | <impl_declaration> | <enum_declaration> | <return_statement> | <break_statement> | <continue_statement> | <try_statement> | <expression_statement> | ";"
<variable_declaration> ::= "let" <identifier> ["=" <expression>] ";"
<if_statement> ::= "if" "(" <expression> ")" <block> ["else" (<if_statement> | <block>)]
<while_statement> ::= "while" "(" <expression> ")" <block>
<for_statement> ::= "for" "(" "let" <identifier> "in" <expression> ")" <block>
<function_declaration> ::= "fn" <identifier> "(" [<identifier> ("," <identifier>)*] ")" <block>
<struct_declaration> ::= "struct" <identifier> "{" (<identifier> ";")* "}"
<impl_declaration> ::= "impl" <identifier> "{" <function_declaration>* "}"
<enum_declaration> ::= "enum" <identifier> "{" (<identifier> ("," <identifier>)*)? "}"
<return_statement> ::= "return" [<expression>] ";"
<break_statement> ::= "break" ";"
<continue_statement> ::= "continue" ";"
<try_statement> ::= "try" <block> "catch" <block> ["finally" <block>]
<expression_statement> ::= <expression> [";"]
<expression> ::= <assignment>
<assignment> ::= <pipe_declaration> | <pipe_declaration> ("=" | "+=" | "-=" | "*=" | "/=") <expression>
<pipe_declaration> ::= <logical_or> ("pipe" <logical_or>)*
<logical_or> ::= <logical_and> ("||" <logical_and>)*
<logical_and> ::= <equality> ("&&" <equality>)*
<equality> ::= <relational> ("==" | "!=" <relational>)*
<relational> ::= <additive> ("<" | ">" | "<=" | ">=" <additive>)*
<additive> ::= <multiplicative> ("+" | "-" <multiplicative>)*
<multiplicative> ::= <unary> ("*" | "/" | "%" <unary>)*
<unary> ::= ("!" | "-") <unary> | <primary>
<primary> ::= <literal> | <identifier> | "(" <expression> ")" | "[" <array_literal> "]" | "{" <object_literal> "}" | "lambda" <lambda_params> ":" <expression> | "new" <identifier> "{" <property_list> "}" | <call_expression> | <member_expression>
<literal> ::= <number> | <string> | "true" | "false" | "null"
<array_literal> ::= "[" [<expression> ("," <expression>)*] "]"
<object_literal> ::= "{" [<property> ("," <property>)*] "}"
<property> ::= <identifier> ":" <expression>
<lambda_params> ::= [<identifier> ("," <identifier>)*] | "(" [<identifier> ("," <identifier>)*] ")"
<call_expression> ::= <primary> "(" [<expression> ("," <expression>)*] ")"
<member_expression> ::= <primary> ("." <identifier> | "[" <expression> "]")
<identifier> ::= [a-zA-Z_][a-zA-Z0-9_]*
<number> ::= [0-9]+(\.[0-9]+)?
<string> ::= '"' ([^"\\]|\\.)* '"'
<block> ::= "{" <statement>* "}"
```
