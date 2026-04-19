/*
 * COMP Project
 *
 * Authors:
 *   David Pedrosa 2021275573
 *   Rodrigo Manão 2023207589
 */

%{

#include <stdio.h>

#include "ast.h"

int yylex(void);
void yyerror(char *);

struct node *ast;

%}

%union {
    char *lexeme;
    struct node *node;
}

/* Tokens com valor semantico */
%token <lexeme> IDENTIFIER NATURAL DECIMAL STRLIT BOOLLIT

/* Types */
%token BOOL INT DOUBLE STRING VOID

/* Keywords */
%token CLASS PUBLIC STATIC RETURN IF ELSE WHILE

/* Predefined methods */
%token PRINT PARSEINT DOTLENGTH

/* Operators */
%token PLUS MINUS STAR DIV MOD
%token EQ NE LT LE GT GE
%token AND OR NOT XOR
%token LSHIFT RSHIFT

/* Punctuation */
%token ASSIGN COMMA SEMICOLON ARROW
%token LBRACE RBRACE LPAR RPAR LSQ RSQ

/* Reserved words */
%token RESERVED

/* Nonterminal semantic types */
%type <node> program classMembers classMember
%type <node> methodDecl fieldDecl fieldDeclarations
%type <node> methodHeader methodBody methodBodyItems
%type <node> formalParams formalParamsList type
%type <node> varDecl idList statement statementList
%type <node> methodInvocation arguments exprList
%type <node> parseArgs assignment expr expr2

/* Precedencia usada para o dangling else e para os operadores unarios */
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

%%

/* Program */
program
    : CLASS IDENTIFIER LBRACE classMembers RBRACE {
        ast = newnode(Program, NULL);
        addchild(ast, newnode(Identifier, $2));

        struct node_list *child = $4->children->next;
        while (child != NULL) {
            addchild(ast, child->node);
            child = child->next;
        }
    }
    ;

/* Class members */
methodDecl
    : PUBLIC STATIC methodHeader methodBody {
        $$ = newnode(MethodDecl, NULL);
        addchild($$, $3);
        addchild($$, $4);
    }
    ;

fieldDecl
    : PUBLIC STATIC type IDENTIFIER fieldDeclarations SEMICOLON {

        /* Uj FieldDecl para cada identifier na linha */
        $$ = newnode(Program, NULL); /* list container */

        struct node *first = newnode(FieldDecl, NULL);
        addchild(first, $3);
        addchild(first, newnode(Identifier, $4));
        addchild($$, first);

        if ($5 != NULL) {
            struct node_list *child = $5->children->next;
            while (child != NULL) {
                struct node *next = newnode(FieldDecl, NULL);
                struct node *type_clone = newnode($3->category, NULL);
                addchild(next, type_clone);
                addchild(next, child->node);
                addchild($$, next);
                child = child->next;
            }
        }
    }
    | error SEMICOLON {
        $$ = NULL;
    }
    ;

fieldDeclarations
    : fieldDeclarations COMMA IDENTIFIER {
        $$ = $1;
        addchild($$, newnode(Identifier, $3));
    }
    | /* empty */ {
        $$ = newnode(Program, NULL);
    }
    ;

/* Types */
type
    : BOOL   { $$ = newnode(Bool, NULL); }
    | INT    { $$ = newnode(Int, NULL); }
    | DOUBLE { $$ = newnode(Double, NULL); }
    ;

classMembers
    : classMembers classMember {
        $$ = $1;
        if ($2 != NULL) {
            /* fieldDecl retorna uma lista de Program com multiplos filhos FieldDecl */
            if ($2->category == Program) {
                struct node_list *child = $2->children->next;
                while (child != NULL) {
                    addchild($$, child->node);
                    child = child->next;
                }
            } else {
                addchild($$, $2);
            }
        }
    }
    | /* empty */ {
        $$ = newnode(Program, NULL);
    }
    ;

classMember
    : methodDecl  { $$ = $1; }
    | fieldDecl   { $$ = $1; }
    | SEMICOLON   { $$ = NULL; }
    ;


/* Method header */
methodHeader
    : type IDENTIFIER LPAR formalParams RPAR {
        $$ = newnode(MethodHeader, NULL);
        addchild($$, $1);
        addchild($$, newnode(Identifier, $2));
        addchild($$, $4);
    }
    | VOID IDENTIFIER LPAR formalParams RPAR {
        $$ = newnode(MethodHeader, NULL);
        addchild($$, newnode(Void, NULL));
        addchild($$, newnode(Identifier, $2));
        addchild($$, $4);
    }
    ;

/* Formal parameters (MethodParams root) */
formalParams
    : type IDENTIFIER formalParamsList {
        $$ = newnode(MethodParams, NULL);

        struct node *first_param = newnode(ParamDecl, NULL);
        addchild(first_param, $1);
        addchild(first_param, newnode(Identifier, $2));
        addchild($$, first_param);

        if ($3 != NULL) {
            struct node_list *child = $3->children->next;
            while (child != NULL) {
                addchild($$, child->node);
                child = child->next;
            }
        }
    }
    | STRING LSQ RSQ IDENTIFIER {
        $$ = newnode(MethodParams, NULL);

        struct node *param = newnode(ParamDecl, NULL);
        addchild(param, newnode(StringArray, NULL));
        addchild(param, newnode(Identifier, $4));
        addchild($$, param);
    }
    | /* empty */ {
        $$ = newnode(MethodParams, NULL); 
    }
    ;

/* Lista de parametros adicionais (temporarios) */
formalParamsList
    : formalParamsList COMMA type IDENTIFIER {
        $$ = $1;
        struct node *param = newnode(ParamDecl, NULL);
        addchild(param, $3);
        addchild(param, newnode(Identifier, $4));
        addchild($$, param);
    }
    | /* empty */ {
        $$ = newnode(Program, NULL);
    }
    ;

/* Method body */
methodBody
    : LBRACE methodBodyItems RBRACE {
        $$ = newnode(MethodBody, NULL);
        if ($2 != NULL) {
            struct node_list *child = $2->children->next;
            while (child != NULL) {
                addchild($$, child->node);
                child = child->next;
            }
        }
    }
    ;

methodBodyItems
    : methodBodyItems statement {
        $$ = $1;
        if ($2 != NULL) {
            addchild($$, $2);
        }
    }
    | methodBodyItems varDecl {
        $$ = $1;
        if ($2 != NULL) {
            /* varDecl retorna uma lista com 1 VarDecl por identifier. */

            struct node_list *child = $2->children->next;
            while (child != NULL) {
                addchild($$, child->node);
                child = child->next;
            }
        }
    }
    | /* empty */ {
        $$ = newnode(Program, NULL);
    }
    ;

/* Variable declarations */
varDecl
    : type IDENTIFIER idList SEMICOLON {
        $$ = newnode(Program, NULL);

        struct node *first_var = newnode(VarDecl, NULL);
        addchild(first_var, $1);
        addchild(first_var, newnode(Identifier, $2));
        addchild($$, first_var);

        if ($3 != NULL) {
            struct node_list *child = $3->children->next;
            while (child != NULL) {
                struct node *next_var = newnode(VarDecl, NULL);

                /* Cloan o tipo do no  (o mesmo ponteiro nao pode ser usado para varios VarDecls) */
                struct node *type_clone = newnode($1->category, NULL);

                addchild(next_var, type_clone);
                addchild(next_var, child->node);

                addchild($$, next_var);
                child = child->next;
            }
        }
    }
    ;

idList
    : idList COMMA IDENTIFIER {
        $$ = $1;
        addchild($$, newnode(Identifier, $3));
    }
    | /* empty */ {
        $$ = newnode(Program, NULL);
    }
    ;


/* Statements */
statement
    : LBRACE statementList RBRACE {
        struct node_list *child = $2->children->next;
        int count = 0;
        struct node *single_child = NULL;

        while (child != NULL) {
            count++;
            single_child = child->node;
            child = child->next;
        }

        if (count == 0) {
            $$ = NULL;
        } else if (count > 1) {
            $$ = newnode(Block, NULL);
            child = $2->children->next;
            while (child != NULL) {
                addchild($$, child->node);
                child = child->next;
            }
        } else {
            $$ = single_child;
        }
    }
    | IF LPAR expr RPAR statement %prec IFX {
        $$ = newnode(If, NULL);
        addchild($$, $3);
        addchild($$, ($5 != NULL) ? $5 : newnode(Block, NULL));
        addchild($$, newnode(Block, NULL));
    }
    | IF LPAR expr RPAR statement ELSE statement {
        $$ = newnode(If, NULL);
        addchild($$, $3);
        addchild($$, ($5 != NULL) ? $5 : newnode(Block, NULL));
        addchild($$, ($7 != NULL) ? $7 : newnode(Block, NULL));
    }
    | WHILE LPAR expr RPAR statement {
        $$ = newnode(While, NULL);
        addchild($$, $3);
        addchild($$, ($5 != NULL) ? $5 : newnode(Block, NULL));
    }
    | RETURN SEMICOLON { $$ = newnode(Return, NULL); }
    | RETURN expr SEMICOLON { $$ = newnode(Return, NULL); addchild($$, $2); }
    | methodInvocation SEMICOLON { $$ = $1; }
    | assignment SEMICOLON { $$ = $1; }
    | parseArgs SEMICOLON { $$ = $1; }
    | PRINT LPAR expr RPAR SEMICOLON { $$ = newnode(Print, NULL); addchild($$, $3); }
    | PRINT LPAR STRLIT RPAR SEMICOLON { $$ = newnode(Print, NULL); addchild($$, newnode(StrLit, $3)); }
    | SEMICOLON { $$ = NULL; }
    | error SEMICOLON { $$ = NULL; }
    ;

statementList
    : statementList statement {
        $$ = $1;
        if ($2 != NULL) addchild($$, $2);
    }
    | /* empty */ { $$ = newnode(Program, NULL); }
    ;

/* Method invocation */
methodInvocation
    : IDENTIFIER LPAR arguments RPAR {
        $$ = newnode(Call, NULL);
        addchild($$, newnode(Identifier, $1));

        if ($3 != NULL) {
            struct node_list *child = $3->children->next;
            while (child != NULL) {
                addchild($$, child->node);
                child = child->next;
            }
        }
    }
    | IDENTIFIER LPAR error RPAR { $$ = NULL; }
    ;

arguments
    : exprList { $$ = $1; }
    | /* vazio */ { $$ = NULL; }
    ;

exprList
    : expr { $$ = newnode(Program, NULL); addchild($$, $1); }
    | exprList COMMA expr { $$ = $1; addchild($$, $3); }
    ;

/* Assignment & ParseArgs */
assignment
    : IDENTIFIER ASSIGN expr {
        $$ = newnode(Assign, NULL);
        addchild($$, newnode(Identifier, $1));
        addchild($$, $3);
    }
    ;

parseArgs
    : PARSEINT LPAR IDENTIFIER LSQ expr RSQ RPAR {
        $$ = newnode(ParseArgs, NULL);
        addchild($$, newnode(Identifier, $3));
        addchild($$, $5);
    }
    | PARSEINT LPAR error RPAR { $$ = NULL; }
    ;

/* Tive que mudar aqui pq ele chumbava o assing e all _errors por causa do assignments nas expressoes
/* A entry point principal que aceita assignments soltos */
expr
    : assignment { $$ = $1; }
    | expr2      { $$ = $1; }
    ;

/* Expressões matemáticas e lógicas (não aceitam assignments soltos lá dentro) */
expr2
    : expr2 PLUS expr2 { $$ = newnode(Add, NULL); addchild($$, $1); addchild($$, $3); }
    | expr2 MINUS expr2 { $$ = newnode(Sub, NULL); addchild($$, $1); addchild($$, $3); }
    | expr2 STAR expr2 { $$ = newnode(Mul, NULL); addchild($$, $1); addchild($$, $3); }
    | expr2 DIV expr2 { $$ = newnode(Div, NULL); addchild($$, $1); addchild($$, $3); }
    | expr2 MOD expr2 { $$ = newnode(Mod, NULL); addchild($$, $1); addchild($$, $3); }

    | expr2 AND expr2 { $$ = newnode(And, NULL); addchild($$, $1); addchild($$, $3); }
    | expr2 OR expr2 { $$ = newnode(Or, NULL); addchild($$, $1); addchild($$, $3); }
    | expr2 XOR expr2 { $$ = newnode(Xor, NULL); addchild($$, $1); addchild($$, $3); }

    | expr2 LSHIFT expr2 { $$ = newnode(Lshift, NULL); addchild($$, $1); addchild($$, $3); }
    | expr2 RSHIFT expr2 { $$ = newnode(Rshift, NULL); addchild($$, $1); addchild($$, $3); }

    | expr2 EQ expr2 { $$ = newnode(Eq, NULL); addchild($$, $1); addchild($$, $3); }
    | expr2 GT expr2 { $$ = newnode(Gt, NULL); addchild($$, $1); addchild($$, $3); }
    | expr2 GE expr2 { $$ = newnode(Ge, NULL); addchild($$, $1); addchild($$, $3); }
    | expr2 LT expr2 { $$ = newnode(Lt, NULL); addchild($$, $1); addchild($$, $3); }
    | expr2 LE expr2 { $$ = newnode(Le, NULL); addchild($$, $1); addchild($$, $3); }
    | expr2 NE expr2 { $$ = newnode(Ne, NULL); addchild($$, $1); addchild($$, $3); }

    | NOT expr2 { $$ = newnode(Not, NULL); addchild($$, $2); }
    | MINUS expr2 %prec UMINUS { $$ = newnode(Minus, NULL); addchild($$, $2); }
    | PLUS expr2 %prec UMINUS { $$ = newnode(Plus, NULL); addchild($$, $2); }

    | LPAR expr RPAR { $$ = $2; }
    | LPAR error RPAR { $$ = NULL; }
    
    | methodInvocation { $$ = $1; }
    | parseArgs { $$ = $1; }

    | IDENTIFIER { $$ = newnode(Identifier, $1); }
    | IDENTIFIER DOTLENGTH { $$ = newnode(Length, NULL); addchild($$, newnode(Identifier, $1)); }
    
    | NATURAL { $$ = newnode(Natural, $1); }
    | DECIMAL { $$ = newnode(Decimal, $1); }
    | BOOLLIT { $$ = newnode(BoolLit, $1); }
    ;
