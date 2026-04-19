#ifndef _AST_H
#define _AST_H

enum category {
    Program, FieldDecl, VarDecl, MethodDecl, MethodHeader, MethodParams, ParamDecl, MethodBody,
    Block, If, While, Return, Call, Print, ParseArgs, Assign,
    Or, And, Eq, Sub, Mul, Div, Mod, Ne, Lshift, Lt, Gt, Rshift, Le, Xor, Not, Ge, Add, Minus, Plus, Length,
    Bool, BoolLit, Double, Decimal, Identifier, Int, Natural, StrLit, StringArray, Void
};

/* categoria de nomes usadas pela func show, tem a mesma ordem do enum de cima*/
#define names { \
    "Program", "FieldDecl", "VarDecl", "MethodDecl", "MethodHeader", "MethodParams", "ParamDecl", "MethodBody", \
    "Block", "If", "While", "Return", "Call", "Print", "ParseArgs", "Assign", \
    "Or", "And", "Eq", "Sub", "Mul", "Div", "Mod", "Ne", "Lshift", "Lt", "Gt", "Rshift", "Le", "Xor", "Not", "Ge", "Add", "Minus", "Plus", "Length", \
    "Bool", "BoolLit", "Double", "Decimal", "Identifier", "Int", "Natural", "StrLit", "StringArray", "Void" \
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
