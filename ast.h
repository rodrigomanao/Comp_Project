#ifndef _AST_H
#define _AST_H

enum category { 
    Program, MethodDecl, FieldDecl, MethodHeader, FormalParams, MethodBody, VarDecl,
    Identifier, Natural, Decimal, Boollit, Strlit, 
    Bool, Int, Double, Void, 
    Add, Sub, Mul, Div, Mod, 
    And, Or, Xor, Lshift, Rshift, 
    Eq, Ge, Gt, Le, Lt, Ne, 
    Minus, Plus, Not, 
    ParseArgs, MethodInvocation, Assignment, Length, 
    If, While, Return, Print, Block, Statement, Parseint, Class
};

/* category names used by show; keep order in sync with enum above */
// FALTAM CENAS JA MUDO
#define names { \ 
    "Program", "Function", "Parameters", "Parameter", "Arguments", \
    "Integer", "Double", "Identifier", "Natural", "Decimal", \
    "Call", "If", "Add", "Sub", "Mul", "Div" \
}

struct node {
    enum category category;
    char *token;
    struct node_list *children;
};

struct node_list {
    struct node *node;
    struct node_list *next;
};

struct node *newnode(enum category category, char *token);
void addchild(struct node *parent, struct node *child);
void show(struct node *node, int depth);

extern char *category_name[];

#endif
