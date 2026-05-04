/*
 * COMP Project
 * Authors: David Pedrosa 2021275573, Rodrigo Manão 2023207589
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <math.h>
#include "semantics.h"
#include "ast.h"

// --- 1. PROTÓTIPOS E GLOBAIS ---
struct symbol_list *search_symbol(struct symbol_table *table, char *identifier);
enum type check_expression(struct symbol_table *local_table, struct node *expr);
void check_method_body(struct symbol_table *local_table, struct node *body);
struct node *get_child(struct node *parent, int index);

struct symbol_table *global_table = NULL;
struct symbol_table *tables_list = NULL;
int semantic_errors = 0;
struct checked_list {
    char *name;
    struct checked_list *next;
};

// --- 2. AUXILIARES ---

// Retorna o n-ésimo filho de um nó da Árvore de Sintaxe Abstrata (AST)
struct node *get_child(struct node *parent, int index) {
    if (parent == NULL || parent->children == NULL) return NULL;
    struct node_list *current = parent->children->next;
    while (current != NULL && index > 0) {
        current = current->next;
        index--;
    }
    return (current != NULL) ? current->node : NULL;
}

// Converte um tipo interno (enum) para a sua representação em texto (ex: type_int -> "int")
const char *type_to_string(enum type t) {
    switch(t) {
        case type_int: return "int";
        case type_double: return "double";
        case type_boolean: return "boolean";
        case type_void: return "void";
        case type_string_array: return "String[]";
        case type_undef: return "undef";
        default: return "none";
    }
}

// Mapeia a categoria da AST para o nosso tipo interno (ex: nó Int -> type_int)
enum type category_to_type(enum category cat) {
    switch(cat) {
        case Int: return type_int;
        case Double: return type_double;
        case Bool: return type_boolean;
        case StringArray: return type_string_array;
        case Void: return type_void;
        default: return type_undef;
    }
}

// Retorna o nome original do tipo baseado na categoria da AST
const char *get_ast_type_name(enum category cat) {
    switch(cat) {
        case Int: return "int";
        case Double: return "double";
        case Bool: return "boolean";
        case StringArray: return "String[]";
        case Void: return "void";
        default: return "";
    }
}

// Devolve o símbolo visual de um operador (útil para imprimir erros)
const char *get_op_sym(enum category cat) {
    switch(cat) {
        case Add: return "+"; case Sub: return "-"; case Mul: return "*";
        case Div: return "/"; case Mod: return "%"; case Assign: return "=";
        case Eq: return "=="; case Ne: return "!="; case Lt: return "<";
        case Le: return "<="; case Gt: return ">"; case Ge: return ">=";
        case And: return "&&"; case Or: return "||"; case Xor: return "^";
        case Not: return "!"; case Minus: return "-"; case Plus: return "+";
        default: return "";
    }
}

// Verifica se 'actual' pode ser atribuído a 'formal' (inclui a regra widening: int entra em double)
int is_compatible(enum type actual, enum type formal) {
    if (actual == type_undef || formal == type_undef) return 0;
    if (actual == formal) return 1;
    if (actual == type_int && formal == type_double) return 1;
    return 0;
}

// Converte uma string com o nome do tipo ("int") para o enum respetivo (type_int)
enum type string_to_type(char *s) {
    if (strcmp(s, "int") == 0) return type_int;
    if (strcmp(s, "double") == 0) return type_double;
    if (strcmp(s, "boolean") == 0) return type_boolean;
    if (strcmp(s, "void") == 0) return type_void;
    if (strcmp(s, "String[]") == 0) return type_string_array;
    return type_undef;
}

// Verifica se uma lista de argumentos encaixa na assinatura de um método (usando widening)
int is_method_compatible(char *method_sig, enum type *args, int arg_count) {
    char *sig_copy = strdup(method_sig);
    char *token = strtok(sig_copy, "(,) ");
    int i = 0;

    while (token != NULL && i < arg_count) {
        enum type formal = string_to_type(token);
        if (!is_compatible(args[i], formal)) { 
            free(sig_copy);
            return 0;
        }
        token = strtok(NULL, "(,) ");
        i++;
    }
    
    int result = (token == NULL && i == arg_count);
    free(sig_copy);
    return result;
}

// Constrói uma string com a assinatura dos argumentos reais (ex: "(int,double)")
void build_sig_string(char *buffer, enum type *args, int arg_count) {
    strcpy(buffer, "(");
    for (int i = 0; i < arg_count; i++) {
        strcat(buffer, type_to_string(args[i]));
        if (i < arg_count - 1) strcat(buffer, ",");
    }
    strcat(buffer, ")");
}

// Remove os underscores de um número literal (ex: "1_000" -> "1000")
void clean_underscores(char *dest, const char *src) {
    while (*src) {
        if (*src != '_') *dest++ = *src;
        src++;
    }
    *dest = '\0';
}

// Verifica se um número tem apenas zeros (usado para detetar underflows legítimos)
int is_zero_literal(const char *s) {
    for (int i = 0; s[i] != '\0'; i++) {
        if (s[i] == 'e' || s[i] == 'E') break;
        if (s[i] >= '1' && s[i] <= '9') return 0;
    }
    return 1;
}

// --- 3. GESTÃO DE TABELAS ---

// Aloca memória e inicializa uma nova Tabela de Símbolos vazia
struct symbol_table *create_table(char *name) {
    struct symbol_table *new_t = malloc(sizeof(struct symbol_table));
    new_t->name = strdup(name);
    new_t->symbols = NULL;
    new_t->next = NULL;
    return new_t;
}

// Adiciona uma nova tabela ao final da lista global de tabelas do compilador
void add_table(struct symbol_table *new_table) {
    if (tables_list == NULL) tables_list = new_table;
    else {
        struct symbol_table *aux = tables_list;
        while (aux->next != NULL) aux = aux->next;
        aux->next = new_table;
    }
}

// Procura e devolve uma tabela de símbolos específica pelo seu nome (ex: "Method main(String[])")
struct symbol_table *search_table(char *name) {
    struct symbol_table *t = tables_list;
    while (t != NULL) {
        if (strcmp(t->name, name) == 0) return t;
        t = t->next;
    }
    return NULL;
}

// Procura uma variável ou método dentro de uma tabela de símbolos específica
struct symbol_list *search_symbol(struct symbol_table *table, char *identifier) {
    if (table == NULL) return NULL;
    struct symbol_list *aux = table->symbols;
    while (aux != NULL) {
        if (strcmp(aux->identifier, identifier) == 0) return aux;
        aux = aux->next;
    }
    return NULL;
}

// Insere um símbolo na tabela. Se ele já existir (duplicado), imprime o erro apropriado e retorna NULL.
struct symbol_list *insert_symbol(struct symbol_table *table, char *identifier, enum type type, char *param_types, int is_param, int line, int col) {
    if (strcmp(identifier, "_") == 0) {
        printf("Line %d, col %d: Symbol _ is reserved\n", line, col);
        semantic_errors++;
        return NULL;
    }
    struct symbol_list *aux = table->symbols;
    while (aux != NULL) {
        int same_name = (strcmp(aux->identifier, identifier) == 0);
        int same_params = (param_types == NULL && aux->param_types == NULL) || 
                          (param_types && aux->param_types && strcmp(aux->param_types, param_types) == 0);
        if (same_name && same_params) {
            if(param_types) printf("Line %d, col %d: Symbol %s%s already defined\n", line, col, identifier, param_types);
            else printf("Line %d, col %d: Symbol %s already defined\n", line, col, identifier);
            semantic_errors++; return NULL; 
        }
        aux = aux->next;
    }
    struct symbol_list *new_s = malloc(sizeof(struct symbol_list));
    new_s->identifier = strdup(identifier);
    new_s->type = type;
    new_s->param_types = param_types ? strdup(param_types) : NULL;
    new_s->is_param = is_param;
    new_s->next = NULL;
    if (table->symbols == NULL) table->symbols = new_s;
    else {
        aux = table->symbols;
        while (aux->next != NULL) aux = aux->next;
        aux->next = new_s;
    }
    return new_s;
}

// Constrói a string de assinatura do método a partir da AST (usado ao registar um método)
char *build_param_signature(struct node *method_params) {
    char buffer[16384] = "(";
    int first = 1;
    struct node_list *curr = (method_params && method_params->children) ? method_params->children->next : NULL;
    while (curr) {
        if (!first) strcat(buffer, ",");
        strcat(buffer, get_ast_type_name(get_child(curr->node, 0)->category));
        first = 0; curr = curr->next;
    }
    strcat(buffer, ")");
    return strdup(buffer);
}

// --- 4. VERIFICAÇÃO E ANOTAÇÃO (PASSAGEM 2) ---

// Compara exatidão absoluta entre os argumentos da chamada e a assinatura do método
int match_arguments(char *method_sig, enum type *args, int count) {
    char buffer[512];
    strcpy(buffer, "(");
    for (int i = 0; i < count; i++) {
        strcat(buffer, type_to_string(args[i]));
        if (i < count - 1) strcat(buffer, ",");
    }
    strcat(buffer, ")");
    return (strcmp(method_sig, buffer) == 0);
}

// Verifica se os tipos da chamada podem ser promovidos para os tipos do método
int check_method_params(char *sig, enum type *args, int arg_count) {
    char *copy = strdup(sig);
    char *token = strtok(copy, "(,) ");
    int i = 0;

    while (token != NULL && i < arg_count) {
        enum type formal_type = string_to_type(token); // int, double, boolean...
        if (!is_compatible(args[i], formal_type)) { // int -> double é OK
            free(copy);
            return 0;
        }
        token = strtok(NULL, "(,) ");
        i++;
    }

    // O número de argumentos tem de ser exato
    int result = (token == NULL && i == arg_count);
    free(copy);
    return result;
}


// ============================================================================
// check_expression: Avalia o tipo de uma expressão e anota a Árvore (AST)
// ============================================================================
enum type check_expression(struct symbol_table *local_table, struct node *expr) {
    if (expr == NULL) return type_none;
    enum type t1, t2;

    switch (expr->category) {
        
        /* ---------------------------------------------------------
         * 1. LITERAIS (Inteiros, Decimais, Booleanos e Strings)
         * --------------------------------------------------------- */
        case Natural: {
            char clean_token[16384];
            clean_underscores(clean_token, expr->token);
            
            unsigned long long val = strtoull(clean_token, NULL, 10);
            
            if (val > 2147483647ULL) {
                printf("Line %d, col %d: Number %s out of bounds\n", expr->line, expr->col, expr->token);
            }
            
            expr->anot_string = strdup("int");
            return type_int;
        }

        case Decimal: {
            char clean_token[2048];
            char *endptr;
            clean_underscores(clean_token, expr->token); 
            
            errno = 0;
            double val = strtod(clean_token, &endptr);

            // Verifica Overflow (valor é demasiado grande e vira infinito)
            int is_inf = (val == HUGE_VAL || val == -HUGE_VAL);
            // Verifica Underflow (valor arredonda para 0.0, mas o literal original não era zero)
            int rounds_to_zero = (val == 0.0 || val == -0.0) && !is_zero_literal(clean_token);

            if (is_inf || rounds_to_zero) {
                printf("Line %d, col %d: Number %s out of bounds\n", expr->line, expr->col, expr->token);
            }
            
            expr->anot_string = strdup("double");
            return type_double;
        }

        case BoolLit: 
            expr->anot_string = strdup("boolean"); 
            return type_boolean;
            
        case StrLit:  
            expr->anot_string = strdup("String"); 
            return type_none; // Strings literais no Juc não têm um tipo operável


        /* ---------------------------------------------------------
         * 2. IDENTIFICADORES (Variáveis e Parâmetros)
         * --------------------------------------------------------- */
        case Identifier: {

            if (strcmp(expr->token, "_") == 0) {
                printf("Line %d, col %d: Symbol _ is reserved\n", expr->line, expr->col);
                expr->anot_string = strdup("undef");
                return type_undef;
            }
            // Primeiro procura no escopo local (variáveis da função)
            struct symbol_list *sym = search_symbol(local_table, expr->token);
            
            // Se não encontrar, procura no escopo global APENAS por variáveis (ignora métodos)
            if (!sym) {
                struct symbol_list *aux = global_table->symbols;
                while (aux != NULL) {
                    // param_types == NULL garante que é uma variável e não um método
                    if (strcmp(aux->identifier, expr->token) == 0 && aux->param_types == NULL) {
                        sym = aux;
                        break;
                    }
                    aux = aux->next;
                }
            }
            
            if (sym) {
                expr->anot_string = strdup(type_to_string(sym->type));
                return sym->type;
            }
            
            // Variável não declarada
            printf("Line %d, col %d: Cannot find symbol %s\n", expr->line, expr->col, expr->token);
            expr->anot_string = strdup("undef");
            return type_undef;
        }


        /* ---------------------------------------------------------
         * 3. OPERADORES ARITMÉTICOS (+, -, *, /, %)
         * --------------------------------------------------------- */
        case Add: case Sub: case Mul: case Div: case Mod:
            t1 = check_expression(local_table, get_child(expr, 0));
            t2 = check_expression(local_table, get_child(expr, 1));
            
            if (t1 == type_int && t2 == type_int) { 
                expr->anot_string = strdup("int"); return type_int; 
            }
            if ((t1 == type_int || t1 == type_double) && (t2 == type_int || t2 == type_double)) {
                expr->anot_string = strdup("double"); return type_double;
            }
            
            printf("Line %d, col %d: Operator %s cannot be applied to types %s, %s\n", 
                   expr->line, expr->col, get_op_sym(expr->category), type_to_string(t1), type_to_string(t2));
            expr->anot_string = strdup("undef");
            return type_undef;


        /* ---------------------------------------------------------
         * 4. OPERADORES RELACIONAIS E DE IGUALDADE
         * --------------------------------------------------------- */
        case Lt: case Le: case Gt: case Ge:
            t1 = check_expression(local_table, get_child(expr, 0));
            t2 = check_expression(local_table, get_child(expr, 1));
            
            expr->anot_string = strdup("boolean"); // Operadores lógicos retornam sempre boolean
            
            // Só aceitam operandos numéricos (int ou double)
            if (!((t1 == type_int || t1 == type_double) && (t2 == type_int || t2 == type_double))) {
                printf("Line %d, col %d: Operator %s cannot be applied to types %s, %s\n", 
                       expr->line, expr->col, get_op_sym(expr->category), type_to_string(t1), type_to_string(t2));
            }
            return type_boolean;

        case Eq: case Ne:
            t1 = check_expression(local_table, get_child(expr, 0));
            t2 = check_expression(local_table, get_child(expr, 1));
            
            expr->anot_string = strdup("boolean");
            
            // Aceitam comparar dois numéricos OU dois booleanos
            if (!((t1 == type_boolean && t2 == type_boolean) || 
                  ((t1 == type_int || t1 == type_double) && (t2 == type_int || t2 == type_double)))) {
                printf("Line %d, col %d: Operator %s cannot be applied to types %s, %s\n", 
                       expr->line, expr->col, get_op_sym(expr->category), type_to_string(t1), type_to_string(t2));
            }
            return type_boolean;


        /* ---------------------------------------------------------
         * 5. OPERADORES LÓGICOS (&&, ||, !)
         * --------------------------------------------------------- */
        case And: case Or: 
            t1 = check_expression(local_table, get_child(expr, 0));
            t2 = check_expression(local_table, get_child(expr, 1));
            
            expr->anot_string = strdup("boolean");
            
            if (!(t1 == type_boolean && t2 == type_boolean)) {
                printf("Line %d, col %d: Operator %s cannot be applied to types %s, %s\n", 
                       expr->line, expr->col, get_op_sym(expr->category), type_to_string(t1), type_to_string(t2));
            }
            return type_boolean;

        case Not:
            t1 = check_expression(local_table, get_child(expr, 0));
            expr->anot_string = strdup("boolean");
            
            if (t1 != type_boolean) {
                printf("Line %d, col %d: Operator ! cannot be applied to type %s\n", 
                       expr->line, expr->col, type_to_string(t1));
            }
            return type_boolean;


        /* ---------------------------------------------------------
         * 6. OPERADORES UNÁRIOS (+ e -) E TRATAMENTO DE OVERFLOW
         * --------------------------------------------------------- */
        case Minus: case Plus: {
            struct node *child = get_child(expr, 0);
            
            t1 = check_expression(local_table, child);
            
            if (t1 == type_int || t1 == type_double) {
                expr->anot_string = strdup(type_to_string(t1));
                return t1;
            }
            
            printf("Line %d, col %d: Operator %s cannot be applied to type %s\n", 
                   expr->line, expr->col, get_op_sym(expr->category), type_to_string(t1));
            expr->anot_string = strdup("undef");
            return type_undef;
        }


        /* ---------------------------------------------------------
         * 7. BITWISE (Ignorados na Análise Semântica do Juc)
         * --------------------------------------------------------- */
        case Lshift: case Rshift: case Xor:
            t1 = check_expression(local_table, get_child(expr, 0));
            t2 = check_expression(local_table, get_child(expr, 1));
            
            if (t1 != type_int || t2 != type_int) {
                printf("Line %d, col %d: Operator %s cannot be applied to types %s, %s\n", 
                       expr->line, expr->col, get_op_sym(expr->category), type_to_string(t1), type_to_string(t2));
            }
            
            expr->anot_string = strdup("int");
            return type_int;


        /* ---------------------------------------------------------
         * 8. ATRIBUIÇÃO (=)
         * --------------------------------------------------------- */
        case Assign:
            t1 = check_expression(local_table, get_child(expr, 0));
            t2 = check_expression(local_table, get_child(expr, 1));
            
            if (t1 != type_none) {
                expr->anot_string = strdup(type_to_string(t1)); 
            }
            
            // É proibido reatribuir o array String[] ou fazer atribuições incompatíveis
            if (t1 == type_string_array || t2 == type_string_array || !is_compatible(t2, t1)) {
                printf("Line %d, col %d: Operator = cannot be applied to types %s, %s\n", 
                       expr->line, expr->col, type_to_string(t1), type_to_string(t2));
            }
            return t1;


        /* ---------------------------------------------------------
         * 9. FUNÇÕES DE SUPORTE (ParseArgs, Length, Call)
         * --------------------------------------------------------- */
        case ParseArgs: {
            struct node *child1 = get_child(expr, 0);
            struct node *child2 = get_child(expr, 1);
            
            t1 = check_expression(local_table, child1); 
            t2 = check_expression(local_table, child2);
            
            if (t1 != type_string_array || t2 != type_int) {
                printf("Line %d, col %d: Operator Integer.parseInt cannot be applied to types %s, %s\n", 
                    expr->line, expr->col, type_to_string(t1), type_to_string(t2));
            }
            
            expr->anot_string = strdup("int"); 
            return type_int;
        }

        case Length:
            t1 = check_expression(local_table, get_child(expr, 0));
            
            if (t1 != type_string_array) {
                printf("Line %d, col %d: Operator .length cannot be applied to type %s\n", 
                       expr->line, expr->col, type_to_string(t1));
            }
            
            expr->anot_string = strdup("int");
            return type_int;

        case Call: {
            struct node *id_node = get_child(expr, 0);
            char *method_name = id_node->token;

            if (strcmp(method_name, "_") == 0) {
                printf("Line %d, col %d: Symbol _ is reserved\n", id_node->line, id_node->col);
                id_node->anot_string = strdup("undef");
                expr->anot_string = strdup("undef");
                return type_undef;
            }

            enum type arg_types[2048];
            int arg_count = 0;

            // 1. Avalia recursivamente os tipos de todos os argumentos
            struct node_list *curr = expr->children->next->next;
            while (curr != NULL && arg_count < 2048) {
                arg_types[arg_count++] = check_expression(local_table, curr->node);
                curr = curr->next;
            }

            char call_sig[16384]; 
            build_sig_string(call_sig, arg_types, arg_count);

            // 2. Procura a melhor correspondência na Tabela Global
            struct symbol_list *sym = global_table->symbols;
            struct symbol_list *exact_match = NULL;
            struct symbol_list *compatible_match = NULL;
            int compatible_count = 0;

            while (sym != NULL) {
                if (sym->param_types && strcmp(sym->identifier, method_name) == 0) {
                    if (strcmp(sym->param_types, call_sig) == 0) {
                        exact_match = sym;
                        break; // Prioridade máxima
                    }
                    if (check_method_params(sym->param_types, arg_types, arg_count)) {
                        compatible_match = sym;
                        compatible_count++; // Guarda para verificar ambiguidades
                    }
                }
                sym = sym->next;
            }

            struct symbol_list *chosen = exact_match ? exact_match : (compatible_count == 1 ? compatible_match : NULL);

            if (chosen) {
                id_node->anot_string = strdup(chosen->param_types);
                expr->anot_string = strdup(type_to_string(chosen->type));
                return chosen->type;
            } else {
                if (compatible_count > 1) {
                    printf("Line %d, col %d: Reference to method %s%s is ambiguous\n", id_node->line, id_node->col, method_name, call_sig);
                } else {
                    printf("Line %d, col %d: Cannot find symbol %s%s\n", id_node->line, id_node->col, method_name, call_sig);
                }
                id_node->anot_string = strdup("undef");
                expr->anot_string = strdup("undef");
                return type_undef;
            }
        }

        default: break;
    }
    
    return type_none;
}

// Analisa e valida uma instrução solta (um If, um While, um Return, Declarações ou Expressões soltas)
void check_statement(struct symbol_table *local_table, struct node *stmt, enum type expected_ret) {
    if (stmt == NULL) return;

    if (stmt->category == VarDecl) {
        struct node *v_type = get_child(stmt, 0);
        struct node *v_id = get_child(stmt, 1);
        insert_symbol(local_table, v_id->token, category_to_type(v_type->category), NULL, 0, v_id->line, v_id->col);
    } 
    else if (stmt->category == If || stmt->category == While) {
        struct node *cond = get_child(stmt, 0);
        enum type cond_type = check_expression(local_table, cond); // Guarda o tipo retornado
        
        // Verifica se a condição é válida (tem de ser boolean)
        if (cond_type != type_boolean) {
            if (stmt->category == If) {
                printf("Line %d, col %d: Incompatible type %s in if statement\n", 
                       cond->line, cond->col, type_to_string(cond_type));
            } else {
                printf("Line %d, col %d: Incompatible type %s in while statement\n", 
                       cond->line, cond->col, type_to_string(cond_type));
            }
        }
        
        // Avalia o corpo do then / loop
        check_statement(local_table, get_child(stmt, 1), expected_ret);
        
        // Avalia o corpo do else (se existir e for um If)
        if (stmt->category == If && get_child(stmt, 2) != NULL) {
            check_statement(local_table, get_child(stmt, 2), expected_ret);
        }
    }
    else if (stmt->category == Return) {
        struct node *ret_expr = get_child(stmt, 0);
        
        if (ret_expr != NULL) {
            // Caso 1: "return expressao;"
            enum type actual_ret = check_expression(local_table, ret_expr);
            
            // Se o método for void, devolver QUALQUER expressão é um erro.
            // Se não for void, verificamos a compatibilidade normal.
            if (expected_ret == type_void || !is_compatible(actual_ret, expected_ret)) {
                printf("Line %d, col %d: Incompatible type %s in return statement\n", 
                       ret_expr->line, ret_expr->col, type_to_string(actual_ret));
            }
        } else {
            // Caso 2: "return;" (vazio)
            if (expected_ret != type_void) {
                printf("Line %d, col %d: Incompatible type void in return statement\n", 
                       stmt->line, stmt->col);
            }
        }
    }
    else if (stmt->category == Block) {
        // Se for um bloco, iteramos pelos filhos e avaliamos cada um
        struct node_list *current = stmt->children->next; 
        while (current != NULL) {
            check_statement(local_table, current->node, expected_ret);
            current = current->next;
        }
    } 
    else if (stmt->category == Print) {
        struct node *print_expr = get_child(stmt, 0);
        enum type t = check_expression(local_table, print_expr);
        if (t == type_void || t == type_undef || t == type_string_array) {
            printf("Line %d, col %d: Incompatible type %s in System.out.print statement\n", 
                   print_expr->line, print_expr->col, type_to_string(t));
            semantic_errors++;
        }
    }
    else {
        // Se for uma expressão solta (Assign, Call, ParseArgs, etc), avaliamos normalmente!
        check_expression(local_table, stmt);
    }
}

// Itera sobre as instruções (statements) do corpo de um método validando cada uma delas
void check_method_body(struct symbol_table *local_table, struct node *body) {
    if (body == NULL) return;
    struct symbol_list *ret_sym = search_symbol(local_table, "return");
    enum type expected_ret = (ret_sym != NULL) ? ret_sym->type : type_void;

    struct node_list *current = body->children->next; 
    while (current != NULL) {
        check_statement(local_table, current->node, expected_ret);
        current = current->next;
    }
}
// --- 5. FUNÇÃO PRINCIPAL ---

// Ponto de entrada da Semântica: 
// 1ª Passagem -> Regista globais e métodos (apanha métodos/variáveis duplicados).
// 2ª Passagem -> Varre os corpos dos métodos para testar tipos de expressões e statements.
void check_program(struct node *program) {
    if (!program || !program->children || !program->children->next) return;
    struct node *id = get_child(program, 0);
    char buf[512]; sprintf(buf, "Class %s", id->token);
    global_table = create_table(buf); add_table(global_table);

    struct node_list *cur = program->children->next->next;
    while (cur) {
        struct node *decl = cur->node;
        if (decl->category == FieldDecl) insert_symbol(global_table, get_child(decl, 1)->token, category_to_type(get_child(decl, 0)->category), NULL, 0, get_child(decl, 1)->line, get_child(decl, 1)->col);
        else if (decl->category == MethodDecl) {
            struct node *h = get_child(decl, 0); char *sig = build_param_signature(get_child(h, 2));
            char m_buf[16384]; sprintf(m_buf, "Method %s%s", get_child(h, 1)->token, sig);
            struct symbol_table *lt = create_table(m_buf);
            insert_symbol(lt, "return", category_to_type(get_child(h, 0)->category), NULL, 0, 0, 0);
            struct node_list *p = (get_child(h, 2) && get_child(h, 2)->children) ? get_child(h, 2)->children->next : NULL;
            while (p) { insert_symbol(lt, get_child(p->node, 1)->token, category_to_type(get_child(p->node, 0)->category), NULL, 1, get_child(p->node, 1)->line, get_child(p->node, 1)->col); p = p->next; }
            if (insert_symbol(global_table, get_child(h, 1)->token, category_to_type(get_child(h, 0)->category), sig, 0, get_child(h, 1)->line, get_child(h, 1)->col)) add_table(lt);
            else { free(lt->name); free(lt); }
            free(sig);
        }
        cur = cur->next;
    }

    struct checked_list *checked = NULL;
    cur = program->children->next->next;
    while (cur) {
        if (cur->node->category == MethodDecl) {
            struct node *h = get_child(cur->node, 0); char *sig = build_param_signature(get_child(h, 2));
            char m_buf[16384]; sprintf(m_buf, "Method %s%s", get_child(h, 1)->token, sig);
            
            int already = 0; struct checked_list *aux = checked;
            while (aux) { if (strcmp(aux->name, m_buf) == 0) { already = 1; break; } aux = aux->next; }
            
            if (!already) {
                struct checked_list *new_node = malloc(sizeof(struct checked_list));
                new_node->name = strdup(m_buf); new_node->next = checked; checked = new_node;
                struct symbol_table *lt = search_table(m_buf);
                if (lt) check_method_body(lt, get_child(cur->node, 1));
            }
            free(sig);
        }
        cur = cur->next;
    }
    while (checked) { struct checked_list *tmp = checked; checked = checked->next; free(tmp->name); free(tmp); }
}
// Percorre a lista global de tabelas de símbolos e imprime o seu conteúdo
void print_symbol_tables() {
    struct symbol_table *t = tables_list;
    while (t != NULL) {
        printf("===== %s Symbol Table =====\n", t->name);
        struct symbol_list *s = t->symbols;
        while (s != NULL) {
            printf("%s\t%s\t%s%s\n", s->identifier, s->param_types ? s->param_types : "", type_to_string(s->type), s->is_param ? "\tparam" : "");
            s = s->next;
        }
        if (t->next != NULL) printf("\n");
        t = t->next;
    }
    printf("\n");
}