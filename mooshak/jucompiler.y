%{
/*
 * COMP Project
 * Authors: David Pedrosa 2021275573, Rodrigo Manão 2023207589
 */

#include <stdio.h>
#include <stdlib.h>
#include "ast.h"
#include "semantics.h"

int yylex(void);
void yyerror(char *);

struct node *ast;
%}

%union {
    struct {
        char *lexeme;
        int line;
        int col;
    } token_info;
    struct node *node;
}

/* Tokens com valor semantico e coordenadas - FUNDAMENTAL PARA META 3 */
%token <token_info> IDENTIFIER NATURAL DECIMAL STRLIT BOOLLIT
%token <token_info> PLUS MINUS STAR DIV MOD ASSIGN EQ NE LT LE GT GE AND OR XOR NOT LSHIFT RSHIFT
%token <token_info> IF ELSE WHILE RETURN PRINT PARSEINT DOTLENGTH
%token <token_info> CLASS PUBLIC STATIC BOOL INT DOUBLE STRING VOID
%token <token_info> RESERVED

/* Pontuação (geralmente não geram erros semânticos, mas podem levar token_info se necessário) */
%token <token_info> COMMA SEMICOLON ARROW LBRACE RBRACE LPAR RPAR LSQ RSQ

/* Tipos semânticos para não-terminais */
%type <node> program classMembers classMember
%type <node> methodDecl fieldDecl fieldDeclarations
%type <node> methodHeader methodBody methodBodyItems
%type <node> formalParams formalParamsList type
%type <node> varDecl idList statement statementList
%type <node> methodInvocation arguments exprList
%type <node> parseArgs assignment expr expr2

/* Precedência */
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
        struct node *id_node = newnode(Identifier, $2.lexeme);
        id_node->line = $2.line; id_node->col = $2.col;
        addchild(ast, id_node);

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
        $$ = newnode(Program, NULL); 
        struct node *first = newnode(FieldDecl, NULL);
        addchild(first, $3);
        struct node *id_node = newnode(Identifier, $4.lexeme);
        id_node->line = $4.line; id_node->col = $4.col;
        addchild(first, id_node);
        addchild($$, first);

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
    | error SEMICOLON { $$ = NULL; }
    ;

fieldDeclarations
    : fieldDeclarations COMMA IDENTIFIER {
        $$ = $1;
        struct node *id_node = newnode(Identifier, $3.lexeme);
        id_node->line = $3.line; id_node->col = $3.col;
        addchild($$, id_node);
    }
    | { $$ = newnode(Program, NULL); }
    ;

type
    : BOOL   { $$ = newnode(Bool, NULL); }
    | INT    { $$ = newnode(Int, NULL); }
    | DOUBLE { $$ = newnode(Double, NULL); }
    ;

classMembers
    : classMembers classMember {
        $$ = $1;
        if ($2 != NULL) {
            if ($2->category == Program) {
                struct node_list *child = $2->children->next;
                while (child != NULL) { addchild($$, child->node); child = child->next; }
            } else { addchild($$, $2); }
        }
    }
    | { $$ = newnode(Program, NULL); }
    ;

classMember
    : methodDecl | fieldDecl | SEMICOLON { $$ = NULL; }
    ;

methodHeader
    : type IDENTIFIER LPAR formalParams RPAR {
        $$ = newnode(MethodHeader, NULL); addchild($$, $1);
        struct node *id_node = newnode(Identifier, $2.lexeme);
        id_node->line = $2.line; id_node->col = $2.col;
        addchild($$, id_node); addchild($$, $4);
    }
    | VOID IDENTIFIER LPAR formalParams RPAR {
        $$ = newnode(MethodHeader, NULL); addchild($$, newnode(Void, NULL));
        struct node *id_node = newnode(Identifier, $2.lexeme);
        id_node->line = $2.line; id_node->col = $2.col;
        addchild($$, id_node); addchild($$, $4);
    }
    ;

formalParams
    : type IDENTIFIER formalParamsList {
        $$ = newnode(MethodParams, NULL);
        struct node *first_param = newnode(ParamDecl, NULL);
        addchild(first_param, $1);
        struct node *id_node = newnode(Identifier, $2.lexeme);
        id_node->line = $2.line; id_node->col = $2.col;
        addchild(first_param, id_node); addchild($$, first_param);
        struct node_list *child = $3->children->next;
        while (child != NULL) { addchild($$, child->node); child = child->next; }
    }
    | STRING LSQ RSQ IDENTIFIER {
        $$ = newnode(MethodParams, NULL);
        struct node *param = newnode(ParamDecl, NULL);
        addchild(param, newnode(StringArray, NULL));
        struct node *id_node = newnode(Identifier, $4.lexeme);
        id_node->line = $4.line; id_node->col = $4.col;
        addchild(param, id_node); addchild($$, param);
    }
    | { $$ = newnode(MethodParams, NULL); }
    ;

formalParamsList
    : formalParamsList COMMA type IDENTIFIER {
        $$ = $1;
        struct node *param = newnode(ParamDecl, NULL);
        addchild(param, $3);
        struct node *id_node = newnode(Identifier, $4.lexeme);
        id_node->line = $4.line; id_node->col = $4.col;
        addchild(param, id_node); addchild($$, param);
    }
    | { $$ = newnode(Program, NULL); }
    ;

methodBody
    : LBRACE methodBodyItems RBRACE {
        $$ = newnode(MethodBody, NULL);
        struct node_list *child = $2->children->next;
        while (child != NULL) { addchild($$, child->node); child = child->next; }
    }
    ;

methodBodyItems
    : methodBodyItems statement { $$ = $1; if ($2 != NULL) addchild($$, $2); }
    | methodBodyItems varDecl {
        $$ = $1;
        struct node_list *child = $2->children->next;
        while (child != NULL) { addchild($$, child->node); child = child->next; }
    }
    | { $$ = newnode(Program, NULL); }
    ;

varDecl
    : type IDENTIFIER idList SEMICOLON {
        $$ = newnode(Program, NULL);
        struct node *first_var = newnode(VarDecl, NULL);
        addchild(first_var, $1);
        struct node *id_node = newnode(Identifier, $2.lexeme);
        id_node->line = $2.line; id_node->col = $2.col;
        addchild(first_var, id_node); addchild($$, first_var);
        struct node_list *child = $3->children->next;
        while (child != NULL) {
            struct node *next_var = newnode(VarDecl, NULL);
            addchild(next_var, newnode($1->category, NULL));
            addchild(next_var, child->node); addchild($$, next_var);
            child = child->next;
        }
    }
    ;

idList
    : idList COMMA IDENTIFIER {
        $$ = $1;
        struct node *id_node = newnode(Identifier, $3.lexeme);
        id_node->line = $3.line; id_node->col = $3.col;
        addchild($$, id_node);
    }
    | { $$ = newnode(Program, NULL); }
    ;

statement
    : LBRACE statementList RBRACE {
        struct node_list *child = $2->children->next;
        int count = 0; struct node *single = NULL;
        while (child != NULL) { count++; single = child->node; child = child->next; }
        if (count == 0) $$ = NULL;
        else if (count > 1) {
            $$ = newnode(Block, NULL);
            child = $2->children->next;
            while (child != NULL) { addchild($$, child->node); child = child->next; }
        } else $$ = single;
    }
    | IF LPAR expr RPAR statement %prec IFX {
        $$ = newnode(If, NULL); $$->line = $1.line; $$->col = $1.col;
        addchild($$, $3); addchild($$, ($5 ? $5 : newnode(Block, NULL))); addchild($$, newnode(Block, NULL));
    }
    | IF LPAR expr RPAR statement ELSE statement {
        $$ = newnode(If, NULL); $$->line = $1.line; $$->col = $1.col;
        addchild($$, $3); addchild($$, ($5 ? $5 : newnode(Block, NULL))); addchild($$, ($7 ? $7 : newnode(Block, NULL)));
    }
    | WHILE LPAR expr RPAR statement {
        $$ = newnode(While, NULL); $$->line = $1.line; $$->col = $1.col;
        addchild($$, $3); addchild($$, ($5 ? $5 : newnode(Block, NULL)));
    }
    | RETURN SEMICOLON { $$ = newnode(Return, NULL); $$->line = $1.line; $$->col = $1.col; }
    | RETURN expr SEMICOLON { $$ = newnode(Return, NULL); $$->line = $1.line; $$->col = $1.col; addchild($$, $2); }
    | methodInvocation SEMICOLON { $$ = $1; }
    | assignment SEMICOLON { $$ = $1; }
    | parseArgs SEMICOLON { $$ = $1; }
    | PRINT LPAR expr RPAR SEMICOLON { 
        $$ = newnode(Print, NULL); $$->line = $1.line; $$->col = $1.col; addchild($$, $3); 
    }
    | PRINT LPAR STRLIT RPAR SEMICOLON { 
        $$ = newnode(Print, NULL); $$->line = $1.line; $$->col = $1.col;
        struct node *s = newnode(StrLit, $3.lexeme); s->line = $3.line; s->col = $3.col; addchild($$, s); 
    }
    | SEMICOLON { $$ = NULL; }
    | error SEMICOLON { $$ = NULL; }
    ;

statementList
    : statementList statement { $$ = $1; if ($2 != NULL) addchild($$, $2); }
    | { $$ = newnode(Program, NULL); }
    ;

methodInvocation
    : IDENTIFIER LPAR arguments RPAR {
        $$ = newnode(Call, NULL);
        $$->line = $1.line;
        $$->col = $1.col;
        
        struct node *id = newnode(Identifier, $1.lexeme); 
        id->line = $1.line; id->col = $1.col;
        addchild($$, id);
        if ($3) { struct node_list *c = $3->children->next; while(c){ addchild($$, c->node); c = c->next; } }
    }
    | IDENTIFIER LPAR error RPAR { $$ = NULL; }
    ;

arguments
    : exprList | { $$ = NULL; }
    ;

exprList
    : expr { $$ = newnode(Program, NULL); addchild($$, $1); }
    | exprList COMMA expr { $$ = $1; addchild($$, $3); }
    ;

assignment
    : IDENTIFIER ASSIGN expr {
        $$ = newnode(Assign, NULL); $$->line = $2.line; $$->col = $2.col;
        struct node *id = newnode(Identifier, $1.lexeme); id->line = $1.line; id->col = $1.col;
        addchild($$, id); addchild($$, $3);
    }
    ;

parseArgs
    : PARSEINT LPAR IDENTIFIER LSQ expr RSQ RPAR {
        $$ = newnode(ParseArgs, NULL); $$->line = $1.line; $$->col = $1.col;
        struct node *id = newnode(Identifier, $3.lexeme); id->line = $3.line; id->col = $3.col;
        addchild($$, id); addchild($$, $5);
    }
    | PARSEINT LPAR error RPAR { $$ = NULL; }
    ;

expr
    : assignment | expr2 { $$ = $1; }
    ;

expr2
    : expr2 PLUS expr2 { $$ = newnode(Add, NULL); $$->line = $2.line; $$->col = $2.col; addchild($$, $1); addchild($$, $3); }
    | expr2 MINUS expr2 { $$ = newnode(Sub, NULL); $$->line = $2.line; $$->col = $2.col; addchild($$, $1); addchild($$, $3); }
    | expr2 STAR expr2 { $$ = newnode(Mul, NULL); $$->line = $2.line; $$->col = $2.col; addchild($$, $1); addchild($$, $3); }
    | expr2 DIV expr2 { $$ = newnode(Div, NULL); $$->line = $2.line; $$->col = $2.col; addchild($$, $1); addchild($$, $3); }
    | expr2 MOD expr2 { $$ = newnode(Mod, NULL); $$->line = $2.line; $$->col = $2.col; addchild($$, $1); addchild($$, $3); }

    | expr2 AND expr2 { $$ = newnode(And, NULL); $$->line = $2.line; $$->col = $2.col; addchild($$, $1); addchild($$, $3); }
    | expr2 OR expr2 { $$ = newnode(Or, NULL); $$->line = $2.line; $$->col = $2.col; addchild($$, $1); addchild($$, $3); }
    | expr2 XOR expr2 { $$ = newnode(Xor, NULL); $$->line = $2.line; $$->col = $2.col; addchild($$, $1); addchild($$, $3); }

    | expr2 LSHIFT expr2 { $$ = newnode(Lshift, NULL); $$->line = $2.line; $$->col = $2.col; addchild($$, $1); addchild($$, $3); }
    | expr2 RSHIFT expr2 { $$ = newnode(Rshift, NULL); $$->line = $2.line; $$->col = $2.col; addchild($$, $1); addchild($$, $3); }
    
    | expr2 EQ expr2 { $$ = newnode(Eq, NULL); $$->line = $2.line; $$->col = $2.col; addchild($$, $1); addchild($$, $3); }
    | expr2 GT expr2 { $$ = newnode(Gt, NULL); $$->line = $2.line; $$->col = $2.col; addchild($$, $1); addchild($$, $3); }
    | expr2 GE expr2 { $$ = newnode(Ge, NULL); $$->line = $2.line; $$->col = $2.col; addchild($$, $1); addchild($$, $3); }
    | expr2 LT expr2 { $$ = newnode(Lt, NULL); $$->line = $2.line; $$->col = $2.col; addchild($$, $1); addchild($$, $3); }
    | expr2 LE expr2 { $$ = newnode(Le, NULL); $$->line = $2.line; $$->col = $2.col; addchild($$, $1); addchild($$, $3); }

    | expr2 NE expr2 { $$ = newnode(Ne, NULL); $$->line = $2.line; $$->col = $2.col; addchild($$, $1); addchild($$, $3); }

    | NOT expr2 { $$ = newnode(Not, NULL); $$->line = $1.line; $$->col = $1.col; addchild($$, $2); }
    | MINUS expr2 %prec UMINUS { $$ = newnode(Minus, NULL); $$->line = $1.line; $$->col = $1.col; addchild($$, $2); }
    | PLUS expr2 %prec UMINUS { $$ = newnode(Plus, NULL); $$->line = $1.line; $$->col = $1.col; addchild($$, $2); }
    
    | LPAR expr RPAR { $$ = $2; }
    | methodInvocation | parseArgs { $$ = $1; }
    | IDENTIFIER { $$ = newnode(Identifier, $1.lexeme); $$->line = $1.line; $$->col = $1.col; }
    | IDENTIFIER DOTLENGTH { 
        $$ = newnode(Length, NULL); $$->line = $2.line; $$->col = $2.col;
        struct node *id = newnode(Identifier, $1.lexeme); id->line = $1.line; id->col = $1.col; addchild($$, id); 
    }
    | NATURAL { $$ = newnode(Natural, $1.lexeme); $$->line = $1.line; $$->col = $1.col; }
    | DECIMAL { $$ = newnode(Decimal, $1.lexeme); $$->line = $1.line; $$->col = $1.col; }
    | BOOLLIT { $$ = newnode(BoolLit, $1.lexeme); $$->line = $1.line; $$->col = $1.col; }
    ;
%%