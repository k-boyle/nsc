{
module Com.NoSyn.Parser.NoSynParser where

import Com.NoSyn.Data.Operators
import Com.NoSyn.Data.Types
import Com.NoSyn.Parser.ConcreteSyntaxTree
import Com.NoSyn.Parser.Token
}

%name parse
%tokentype { Token }
%error { parseError }

%token
    string     { TokenString $$ }
    integer    { TokenInt $$ }
    double     { TokenDouble $$ }
    char       { TokenChar $$ }
    operator   { TokenOperator $$ }
    ','        { TokenComma }
    '('        { TokenParameterOpen }
    ')'        { TokenParameterClose }
    '='        { TokenEquals }
    alias      { TokenAliasKeyword }
    prefix     { TokenPrefixKeyword }
    postfix    { TokenPostfixKeyword }
    tinfix     { TokenInfixKeyword }
    bracketop  { TokenBracketOpKeyword }
    '{'        { TokenCurlyOpen }
    '}'        { TokenCurlyClose }
    '['        { TokenSquareOpen }
    ']'        { TokenSquareClose }
    ';'        { TokenSemicolon }
    '_'        { TokenUnderscore }
    empty      { TokenEmpty }
    ident      { TokenIdent $$ }

%%

FunctionDefinition : ident ident '(' Parameters ')' '{' BlockStatement '}'                             { CFuncDef $1 $2 $4 $7 }
		   | ident OperatorType '_' operator '_' '(' Parameters ')' '{' BlockStatement '}'     { COpOverloadDef $1 $2 $4 $7 $10 }
                   | ident bracketop '_' BracketType '_' '(' Parameters ')' '{' BlockStatement '}'     { CBracketOpOverloadDef $1 $4 $7 $10 } 

ExpressionList : empty                  { CListEmpty }
	       | FilledExpressionList   { CListNonEmpty $1 }

Expression : Constant                         { CEConst $1 }
	   | ident                            { CEIdent $1 }
           | ident '(' ExpressionList ')'     { CEFuncCall $1 $3 }
           | operator Expression              { CEPrefixOp $1 $2 }
           | Expression operator              { CEPostfixOp $2 $1 }
           | Expression operator Expression   { CEInfixOp $2 $1 $3 }

Constant : string    { CCString $1 }
	 | integer   { CCInt $1 }
         | double    { CCDouble $1 }
         | char      { CCChar $1 }

FilledExpressionList : Expression ',' FilledExpressionList   { CMultiExpression $1 $3 }
		     | Expression                            { CFinalExpression $1 }

VariableDeclaration : ident ident        { CVarDec $1 $2 }

Statement : Expression              { CSExpression $1 }
	  | VariableDeclaration     { CSVarDec $1 }

Parameter : ident ident { CParam $1 $2 }

FilledParameters : Parameter ',' FilledParameters     { CMultiParam $1 $3 }
		 | Parameter                          { CFinalParam $1 }

Parameters : empty               { CPEmpty }
	   | FilledParameters    { CPParams $1 }

FilledBlock : Statement ';' FilledBlock         { CMultiStatement $1 $3 }
	    | Statement                         { CFinalStatement $1 }

BlockStatement : empty          { CBlockEmpty }
	       | FilledBlock    { CFilledBlock $1 }

OperatorType : prefix        { Prefix }
	     | postfix       { Postfix }
             | tinfix        { Infix }

BracketType : '(' empty ')' { Parentheses }
	   | '[' empty ']' { Square }
           | '{' empty '}' { Curly }

AliasDefinition : alias ident '=' ident    { CAliasDef $2 $4 }

ProgramStatement : VariableDeclaration     { CPSVarDec $1 }
		 | FunctionDefinition      { CPSFuncDef $1 }
                 | AliasDefinition         { CPSAliasDef $1 }

Program : empty                             { CProgramEnd }
	| ProgramStatement ';' Program      { CProgram $1 $3 }

{
parseError :: [Token] -> a
parseError (x:_) = error $ "Parser Error at " ++ (show x)
}
