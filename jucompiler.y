/*
David Pedrosa 2021275573
Rodrigo Manão 2023207589
*/


/* START definitions section -- C code delimited by %{ ... %} and token declarations */

%{

#include <stdio.h>
#include "ast.h"

int yylex(void);
void yyerror(char *);

struct node *ast;

%}

%union{
    char *lexeme;
    struct node *node;
}

/* tokens com valor semântico */
%token <lexeme> IDENTIFIER NATURAL DECIMAL STRLIT BOOLLIT

/* tipos */
%token BOOL INT DOUBLE STRING VOID

/* palavras-chave */
%token CLASS PUBLIC STATIC RETURN IF ELSE WHILE

/* métodos pré-definidos */
%token PRINT PARSEINT DOTLENGTH

/* operadores aritméticos */
%token PLUS MINUS STAR DIV MOD

/* operadores relacionais */
%token EQ NE LT LE GT GE

/* operadores lógicos */
%token AND OR NOT XOR

/* operadores de shift */
%token LSHIFT RSHIFT

/* pontuação e delimitadores */
%token ASSIGN COMMA SEMICOLON ARROW
%token LBRACE RBRACE LPAR RPAR LSQ RSQ

/* reservados */
%token RESERVED

/* Tipos de nós */

%type<node> program classMembers classMember
%type<node> methodDecl fieldDecl fieldDeclarations
%type<node> methodHeader methodBody methodBodyItems
%type<node> formalParams formalParamsList type
%type<node> varDecl idList statement statementList
%type<node> methodInvocation arguments exprList
%type<node> assignment parseArgs expr


/*Prioridades*/

%nonassoc IFX
%nonassoc ELSE
%right ASSIGN
%left OR
%left AND
%left XOR
%left EQ NE
%left LT LE GT GE
%left LSHIFT RSHIFT
%left PLUS MINUS
%left STAR DIV MOD
%right NOT UMINUS   


/* START grammar rules section -- BNF grammar */

%%

// regra 1

program: CLASS IDENTIFIER LBRACE classMembers RBRACE
    ;

classMembers: classMembers classMember
    | /* vazio */
    ;

classMember
    : methodDecl
    | fieldDecl
    | SEMICOLON
    ;

/* Regra 2 */
methodDecl
    : PUBLIC STATIC methodHeader methodBody
    ;

/* Regra 3 */
fieldDecl
    : PUBLIC STATIC type IDENTIFIER fieldDeclarations SEMICOLON
    | error SEMICOLON
    ;

fieldDeclarations
    : fieldDeclarations COMMA IDENTIFIER
    | /* vazio */
    ;


/* Regra 4*/

type
    : BOOL
    | INT
    | DOUBLE
    ;


/* Regra 5 */
methodHeader
    : type IDENTIFIER LPAR formalParams RPAR
    | VOID IDENTIFIER LPAR formalParams RPAR
    ;

/* Regra 6 e 7 */
formalParams
    : type IDENTIFIER formalParamsList
    | STRING LSQ RSQ IDENTIFIER
    | /* vazio */
    ;

formalParamsList
    : formalParamsList COMMA type IDENTIFIER
    | /* vazio */
    ;

/* Regra 8*/
methodBody
    : LBRACE methodBodyItems RBRACE
    ;

methodBodyItems
    : methodBodyItems statement
    | methodBodyItems varDecl
    | /* vazio */
    ;

/* Regra 9*/
varDecl
    : type IDENTIFIER idList SEMICOLON
    ;

idList
    : idList COMMA IDENTIFIER
    | /* vazio */
    ;

/* Regra 10-15: Statements*/
statement
    : LBRACE statementList RBRACE
    | IF LPAR expr RPAR statement %prec IFX
    | IF LPAR expr RPAR statement ELSE statement
    | WHILE LPAR expr RPAR statement
    | RETURN SEMICOLON
    | RETURN expr SEMICOLON
    | methodInvocation SEMICOLON
    | assignment SEMICOLON
    | parseArgs SEMICOLON
    | PRINT LPAR expr RPAR SEMICOLON
    | PRINT LPAR STRLIT RPAR SEMICOLON
    | SEMICOLON
    | error SEMICOLON  /* Recuperação de erros 2.3 */
    ;

statementList
    : statementList statement
    | /* vazio */
    ;

/*regra 16*/
methodInvocation
    : IDENTIFIER LPAR arguments RPAR
    | IDENTIFIER LPAR error RPAR
    ;

arguments
    : exprList
    | /* vazio */
    ;

exprList
    : expr
    | exprList COMMA expr
    ;

/*17 */
assignment
    : IDENTIFIER ASSIGN expr
    ;
/*18*/
parseArgs
    : PARSEINT LPAR IDENTIFIER LSQ expr RSQ RPAR
    | PARSEINT LPAR error RPAR
    ;


/* 19?*/
expr
    : expr PLUS expr
    | expr MINUS expr
    | expr STAR expr
    | expr DIV expr
    | expr MOD expr

    | expr AND expr
    | expr OR expr
    | expr XOR expr
    | expr LSHIFT expr
    | expr RSHIFT expr

    | expr EQ expr
    | expr GT expr
    | expr GE expr
    | expr LT expr
    | expr LE expr
    | expr NE expr

    | NOT expr
    | MINUS expr %prec UMINUS
    | PLUS expr %prec UMINUS

    | LPAR expr RPAR
    | LPAR error RPAR

    | methodInvocation
    | assignment
    | parseArgs

    | IDENTIFIER
    | IDENTIFIER DOTLENGTH

    | NATURAL
    | DECIMAL
    | BOOLLIT

    ;



/* START subroutines section */

// all needed functions are collected in the .l and ast.* files

