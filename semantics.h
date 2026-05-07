/*
 * COMP Project
 * Authors: David Pedrosa 2021275573, Rodrigo Manão 2023207589
 */

#ifndef _SEMANTICS_H
#define _SEMANTICS_H

#include "ast.h"

enum type {
    type_undef, type_int, type_double, type_boolean, type_void, type_string_array, type_none
};

struct symbol_list {
    char *identifier;
    enum type type;
    char *param_types;     
    int is_param;          
    struct symbol_list *next;
};

struct symbol_table {
    char *name;            
    struct symbol_list *symbols;  
    struct symbol_table *next;    
};

extern struct symbol_table *global_table;
extern struct symbol_table *tables_list;
extern int semantic_errors;

void check_program(struct node *program);
void print_symbol_tables();

struct node *get_child(struct node *parent, int index);
struct symbol_table *search_table(char *name);
struct symbol_list *search_symbol(struct symbol_table *table, char *identifier);

#endif