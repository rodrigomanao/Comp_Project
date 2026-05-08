/*
 * COMP Project
 * Authors: David Pedrosa 2021275573, Rodrigo Manão 2023207589
 */

#ifndef _CODEGEN_H
#define _CODEGEN_H

#include "ast.h"

/* ---- Entrada principal ---- */
void codegen_program(struct node *program);
int  codegen_expression(struct node *expression);

/* ---- Expressoes atomicas ---- */
int codegen_natural(struct node *natural);
int codegen_decimal(struct node *decimal);
int codegen_boollit(struct node *boollit);
int codegen_identifier(struct node *identifier);

/* ---- Operacoes e atribuicao ---- */
int codegen_assign(struct node *assign);
int codegen_math(struct node *math_node, const char *int_op, const char *float_op);
int codegen_cmp(struct node *cmp);

/* ---- Unarios ---- */
int codegen_minus(struct node *minus_node);
int codegen_plus(struct node *plus_node);
int codegen_not(struct node *not_node);

/* ---- Logicos ---- */
int codegen_and(struct node *and_node);
int codegen_or(struct node *or_node);

/* ---- Chamadas e argumentos ---- */
int codegen_call(struct node *call);
int codegen_parseargs(struct node *parseargs);
int codegen_length(struct node *length_node);

/* ---- Statements e control flow ---- */
void codegen_print(struct node *print_node);
void codegen_if(struct node *if_stmt, const char *ret_llvm_type);
void codegen_while(struct node *while_stmt, const char *ret_llvm_type);
void codegen_statement(struct node *stmt, const char *ret_llvm_type);
void codegen_function(struct node *method_decl);
void codegen_var_decl(struct node *vardecl);

/* ---- Helpers internos ---- */
int  codegen_expression_and_cast(struct node *expr, const char *target_type);

int  is_local_variable(char *id_name);
void print_all_allocas(struct node *n);

int  add_string_literal(char *token);
void find_strings(struct node *n);

const char* get_llvm_type(char *anot_string);
const char* type_to_mangle(const char *type_name);

void build_mangled_name_from_sig(const char *base, const char *sig, char *out, size_t out_size);
void build_mangled_name_from_params(const char *base, struct node *params, char *out, size_t out_size);

#endif
