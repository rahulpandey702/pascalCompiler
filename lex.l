%{
#include <stdio.h>
#include <string.h>
#include "syntax.tab.h"
#define YY_DECL extern int yylex()
%}

digit       [0-9]+
letter      [a-zA-Z]
id          {letter}({letter}|{digit}|_)*
str         (\'[^']*\')|(\"[^"]*\")
comment     (\{[^}]*\})|(\/\/.*\n)
ws          [ \t\n]+
%option noyywrap


%%
begin {
  //printf("begin: %s\n",yytext);
  return(_BEGIN) ;
}
end {
  //printf("end: %s\n",yytext);
  return (END) ;
}
while {
  //printf("while: %s\n",yytext);
  return (WHILE) ;
}
for {
  //printf("for: %s\n",yytext);
  return(FOR) ;
}
and {
  //printf("and: %s\n",yytext) ;
  return (AND) ;
}
or {
  //printf("or: %s\n",yytext);
  return (OR) ;
}
not {
  //printf("not: %s\n",yytext) ;
  return (NOT) ;
}
to {
  //printf("to: %s\n",yytext) ;
  return (TO) ;
}
of {
  //printf("of: %s\n",yytext);
  return(OF) ;
}
forward {
  //printf("forward: %s\n",yytext);
  return (FORWARD) ;
}
do {
  //printf("do: %s\n",yytext);
  return (DO) ;
}
div {
  //printf("div: %s\n",yytext);
  return (DIV) ;
}
if {
  //printf("if: %s\n",yytext);
  return(IF);
}
else {
  //printf("else: %s\n",yytext);
  return(ELSE);
}
then {
  //printf("then: %s\n",yytext);
  return(THEN) ;
}
mod {
  //printf("mod: %s\n",yytext);
  return (MOD) ;
}
true {
  //printf("String: %s\n",yytext);
  yylval.sval = strdup(yytext) ;
  return (TRUE_BOOLEAN) ;
}
false {
  //printf("String: %s\n",yytext);
  yylval.sval = strdup(yytext) ;
  return (FALSE_BOOLEAN) ;
}
array {
  //printf("array: %s\n",yytext) ;
  yylval.sval = strdup(yytext) ;
  return (ARRAY) ;
}
function {
  //printf("function: %s\n",yytext);
  return(FUNCTION) ;
}
program {
  //printf("program: %s\n",yytext);
  return (PROGRAM) ;
}
procedure {
  //printf("procedure: %s\n",yytext);
  return (PROCEDURE) ;
}
record {
  //printf("record: %s\n",yytext);
  yylval.sval = strdup(yytext) ;
  return(RECORD) ;
}
type {
  //printf("type: %s\n",yytext);
  return(TYPE) ;
}
{digit} {
  //printf("Sequence of digits\n") ;
  yylval.ival = atoi(yytext);
  return(SEQUENCE_DIGITS) ;
}
var {
  //printf("var: %s\n",yytext);
  return(VAR) ;
}
{id} {
  //printf("Identifier: %s\n",yytext);
  yylval.sval = strdup(yytext) ;
  return (IDENTIFIER) ;
}
{str} {
  //printf("String: %s\n",yytext);
  yylval.sval = strdup(yytext) ;
  return (STRING) ;
}
{ws} {}
{comment} {}

":="    return(ASSIGNMENT) ;
":"    return(COLON) ;
","    return(COMMA) ;
"."    return(DOT) ;
".."    return(DOUBLEDOT) ;
"="    return(EQUAL) ;
"<>"    return(NOTEQUAL) ;
">="    return(GE) ;
"<="    return(LE) ;
">"    return(GT) ;
"<"    return(LT) ;
"["    return(LBRACKET) ;
"]"    return(RBRACKET) ;
"("    return(LPARENTHESIS) ;
")"    return(RPARENTHESIS) ;
"-"    return(MINUS) ;
"+"    return(PLUS) ;
[0-9]+"."[0-9]+   return(FLOATING_POINT) ;
";"    return(SEMICOLON) ;
"/"    return(SLASH) ;
"*"    return(STAR) ;
"**"    return(DOUBLESTAR) ;
"->"   |
"^"    return(UPARROW) ;
%%



/*
struct symbolTable {
  char token[100] ;
  char lexeme[100] ;
} ;
struct symbolTable SYMBOL_TABLE[MAX_SYMBOLS];
int numSymbols = 0 ;

void addSymbol(char *token, char *lexeme) {
   int i ;

   for(i = 0; i < numSymbols ; i++ ) {
      if(strcmp(SYMBOL_TABLE[i].lexeme, lexeme) == 0) {
         return ;
      }
   }
   strcpy(SYMBOL_TABLE[numSymbols].lexeme, lexeme) ;
   strcpy(SYMBOL_TABLE[numSymbols].token, token) ;
   numSymbols++ ;
   return ;
}

int main() {
  int i ;
  yylex();

  printf("\n\nSymbol table:\n") ;
  for(i = 0; i < numSymbols ; i++) {
    printf("#%d Lexeme: %s Token: %s\n", i, SYMBOL_TABLE[i].lexeme, SYMBOL_TABLE[i].token) ;
  }
  return  0 ;
}
*/
