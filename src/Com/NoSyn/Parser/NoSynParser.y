{
module Com.NoSyn.Parser.NoSynParser where

import Com.NoSyn.Data.Operators
import Com.NoSyn.Data.Types
import Com.NoSyn.Parser.ConcreteSyntaxTree
import Com.NoSyn.Parser.Lexer
import Com.NoSyn.Parser.Token
import Com.NoSyn.Parser.TokenLength
import Com.NoSyn.Error.CompilerContext
import Com.NoSyn.Error.SourcePosition
import Com.NoSyn.Error.CompilerStatus
import Com.NoSyn.Error.NonFatalError
import Control.Monad.Trans.Class
}

%name parse
%tokentype { Token }
%error { parseError }
%monad { Cs } { thenCs } { returnCs }
%lexer { monadicLexer } { TokenEOF }

%token
    string     { TokenString $$ }
    nativecode { TokenNativeCode $$ }
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
    native     { TokenNativeKeyword }
    import     { TokenImportKeyword }
    '{'        { TokenCurlyOpen }
    '}'        { TokenCurlyClose }
    '['        { TokenSquareOpen }
    ']'        { TokenSquareClose }
    ';'        { TokenSemicolon }
    '_'        { TokenUnderscore }
    ident      { TokenIdent $$ }

%%

Program : {- empty -}                   {% addSourcePosition $ CProgramEnd }
	| ProgramStatement ';' Program      {% addSourcePosition $ CProgram $1 $3 }
    | FunctionDefinition Program {% \s currentCol l tokenPositions -> do
        cpsFuncDef <- addSourcePosition (CPSFuncDef $1) s currentCol l tokenPositions
        addSourcePosition (CProgramFunction cpsFuncDef $2) s currentCol l tokenPositions 
    }

FunctionDefinition : ident ident '(' Parameters ')' '{' BlockStatement '}'                             {% addSourcePosition $ CFuncDef $1 $2 $4 $7 }
		   | ident OperatorType '_' operator '_' '(' Parameters ')' '{' BlockStatement '}'     {% addSourcePosition $ COpOverloadDef $1 $2 $4 $7 $10 }
                   | native ident ident '(' Parameters ')'                                             {% addSourcePosition $ CFuncDefNative $2 $3 $5}
                   | ident bracketop '_' BracketType '_' '(' Parameters ')' '{' BlockStatement '}'     {% addSourcePosition $ CBracketOpOverloadDef $1 $4 $7 $10 } 

ExpressionList : {- empty -}                  {% addSourcePosition $ CListEmpty }
	       | FilledExpressionList   {% addSourcePosition $ CListNonEmpty $1 }

Expression : Constant                          {% addSourcePosition $ CEConst $1 }
	   | ident                                 {% addSourcePosition $ CEIdent $1 }
           | '(' Expression ')'                {% addSourcePosition $ CEBracketed $2 }
           | Expression '(' ExpressionList ')' {% addSourcePosition $ CEBracketOp Parentheses $1 $3 }
           | Expression '[' ExpressionList ']' {% addSourcePosition $ CEBracketOp Square $1 $3 }
           | Expression '{' ExpressionList '}' {% addSourcePosition $ CEBracketOp Curly $1 $3 }
           | operator Expression               {% addSourcePosition $ CEPrefixOp $1 $2 }
           | Expression operator               {% addSourcePosition $ CEPostfixOp $2 $1 }
           | Expression operator Expression    {% addSourcePosition $ CEInfixOp $2 $1 $3 }

Constant : string    {% addSourcePosition $ CCString $1 }
	 | integer   {% addSourcePosition $ CCInt $1 }
         | double    {% addSourcePosition $ CCDouble $1 }
         | char      {% addSourcePosition $ CCChar $1 }

FilledExpressionList : Expression ',' FilledExpressionList   {% addSourcePosition $ CMultiExpression $1 $3 }
		     | Expression                            {% addSourcePosition $ CFinalExpression $1 }

VariableDeclaration : ident ident        {% addSourcePosition $ CVarDec $1 $2 }

Statement : Expression              {% addSourcePosition $ CSExpression $1 }
	  | VariableDeclaration     {% addSourcePosition $ CSVarDec $1 }

Parameter : ident ident {% addSourcePosition $ CParam $1 $2 }
          | ident operator ident {% \s currentCol l tokenPositions -> let cstElement = CPointerParam $1 $3 in
                let returnVal = addSourcePosition cstElement s currentCol l tokenPositions in
                case $2 of
                    "*" -> returnVal
                    "..." -> addSourcePosition (CVariadicParam $1 $3) s currentCol l tokenPositions
                    actualOperator -> let (sLine, sCol, eLine, eCol) = getTokenPositions cstElement tokenPositions 2 in
                            addNonFatalErrorM
                            (NFE ("Only '*' of '...' can be used on a type to denote an operator. Received operator '" ++ actualOperator ++ "' instead.") s sLine sCol eLine eCol)
                            returnVal
            }

FilledParameters : Parameter ',' FilledParameters     {% addSourcePosition $ CMultiParam $1 $3 }
		 | Parameter                          {% addSourcePosition $ CFinalParam $1 }

Parameters : {- empty -}               {% addSourcePosition $ CPEmpty }
	   | FilledParameters    {% addSourcePosition $ CPParams $1 }

-- Removing from use
FilledBlock : Statement ';' FilledBlock         {% addSourcePosition $ CMultiStatement $1 $3 }
            | Statement ';'                   {% addSourcePosition $ CFinalStatement $1 }

BlockStatement : {- empty -}                           {% addSourcePosition $ CBlockEmpty }
               | FilledBlock    {% addSourcePosition $ CFilledBlock $1 }

OperatorType : prefix        { Prefix }
	     | postfix       { Postfix }
             | tinfix        { Infix }

BracketType : '(' ')' { Parentheses }
	        | '[' ']' { Square }
            | '{' '}' { Curly }

AliasDefinition : alias ident operator ident    {% \s currentCol l tokenPositions ->
                    case $3 of
                        "=" -> addSourcePosition (CAliasDef $2 $4) s currentCol l tokenPositions 
                        _ -> let cstElement = (CAliasDef $2 $4) in
                            let returnVal = addSourcePosition cstElement s currentCol l tokenPositions  in
                            let (sLine, sCol, eLine, eCol) = getTokenPositions cstElement tokenPositions 3 in
                                addNonFatalErrorM
                                (NFE "A '=' operator must be used within an alias definition" s sLine sCol eLine eCol)
                                returnVal
                }
                | native alias ident operator nativecode {% \s currentCol l tokenPositions ->
                    case $4 of
                        "=" -> addSourcePosition (CNativeAliasDef $3 $5) s currentCol l tokenPositions 
                        actualOperator -> let cstElement = CNativeAliasDef $3 $5 in
                            let returnVal = addSourcePosition cstElement s currentCol l tokenPositions in
                            let (sLine, sCol, eLine, eCol) = getTokenPositions cstElement tokenPositions 4 in
                                addNonFatalErrorM
                                (NFE ("A '=' operator must be used within an alias definition. Received operator '" ++ actualOperator ++ "' instead.") s sLine sCol eLine eCol)
                                returnVal
                }

ProgramStatement : VariableDeclaration     {% addSourcePosition $ CPSVarDec $1 }
		 | FunctionDefinition      {% addSourcePosition $ CPSFuncDef $1 }
                 | AliasDefinition         {% addSourcePosition $ CPSAliasDef $1 }
                 | ImportStatement         {% addSourcePosition $ CPSImportStatement $1 }

ImportStatement : import ModuleName            {% addSourcePosition $ CNSImport $2 }
                | native import ModuleName     {% addSourcePosition $ CNativeImport $3 }

-- ModuleName : ident                      {% addSourcePosition $ CModuleIdent $1 }
-- | ident operator ModuleName  {% addSourcePosition $ CPackage $1 $3 }

ModuleName : ident {% addSourcePosition $ CModuleIdent $1 }
           | ident operator ModuleName {% \s currentCol l tokenPositions ->
                case $2 of
                    "." -> addSourcePosition (CPackage $1 $3) s currentCol l tokenPositions
                    actualOperator -> let cstElement = CPackage $1 $3 in
                        let returnVal = addSourcePosition cstElement s currentCol l tokenPositions  in
                        let (sLine, sCol, eLine, eCol) = getTokenPositions cstElement tokenPositions 2 in
                        addNonFatalErrorM
                        (NFE ("package names must be separated by '.' operator. Received operator '" ++ actualOperator ++ "' instead.")  s sLine sCol eLine eCol)
                        returnVal
            }

{
getTokenPositions cstElem tokenPositions tokenNumber =
    (drop ((length tokenPositions) - (tokenLength cstElem) - 1) tokenPositions) !! (tokenNumber - 1)

parseError :: Token -> Cs a
parseError t = getLineNumber `thenCs` \line  -> (failCs ((show t) ++ " at line " ++ (show line)))

thenCs :: Cs a -> (a -> Cs b) -> Cs b
m `thenCs` k = \s currentCol l tokenPositions -> (m s currentCol l tokenPositions) >>= (\x -> k x s currentCol l tokenPositions)

returnCs :: a -> Cs a
returnCs a = \s _ _ _ -> Valid empty a

failCs :: String -> Cs a
failCs err = \s currentCol l tokenmPositions -> PositionedError (l, currentCol, l, currentCol) err "Parsing failure"

-- addSourcePosition :: TokenLength a => a -> Cs a
addSourcePosition a = \s currentCol currentLine tokenPositions ->
    let tokensInProduction = tokenLength a in
    let (startLine, startColumn, _, _) = getTokenPositions a tokenPositions 1 in
    let (_, _, endLine, endColumn) = getTokenPositions a tokenPositions tokensInProduction in
    return $ SourcePosition startLine startColumn endLine endColumn a
}

