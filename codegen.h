#ifndef _CODEGEN_H
#define _CODEGEN_H

#include "ast.h"

void codegen_program(struct node *program);
int codegen_expression(struct node *expression);

int codegen_natural(struct node *natural);
int codegen_decimal(struct node *decimal);
int codegen_identifier(struct node *identifier);
int codegen_assign(struct node *assign);
int codegen_math(struct node *math_node, const char *int_op, const char *float_op);
int codegen_cmp(struct node *cmp);
int codegen_call(struct node *call);
int codegen_parseargs(struct node *parseargs);

void codegen_print(struct node *print_node);
void codegen_if(struct node *if_stmt, const char *ret_llvm_type);
void codegen_while(struct node *while_stmt, const char *ret_llvm_type);
void codegen_statement(struct node *stmt, const char *ret_llvm_type);
void codegen_function(struct node *method_decl);
void codegen_var_decl(struct node *vardecl);

#endif