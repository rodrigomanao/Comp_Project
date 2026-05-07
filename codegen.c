#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "ast.h"
#include "semantics.h"
#include "codegen.h"

int temporary = 1;   
int label = 1;       

// ---- SISTEMA DE SCOPE DE VARIÁVEIS ----
char local_vars[1000][256];
int num_local_vars = 0;

int is_local_variable(char *id_name) {
    for (int i = 0; i < num_local_vars; i++) {
        if (strcmp(local_vars[i], id_name) == 0) return 1;
    }
    return 0; 
}

// ---- SISTEMA DE PRÉ-ALOCAÇÃO ----

char alloced_vars[1000][256];
int num_alloced = 0;

void print_all_allocas(struct node *n) {
    if (!n) return;
    if (n->category == VarDecl) {
        char *v_name = get_child(n, 1)->token;
        int exists = 0;
        for(int i=0; i<num_alloced; i++) {
            if(strcmp(alloced_vars[i], v_name)==0) exists = 1;
        }
        if(!exists) {
            strcpy(alloced_vars[num_alloced++], v_name);
            const char *llvm_type = "i32";
            if (get_child(n, 0)->category == Double) llvm_type = "double";
            else if (get_child(n, 0)->category == Bool) llvm_type = "i1";
            printf("  %%%s = alloca %s\n", v_name, llvm_type);
        }
    }
    if (n->children) {
        struct node_list *child = n->children->next;
        while (child) { print_all_allocas(child->node); child = child->next; }
    }
}

// ---- SISTEMA DE STRINGS GLOBAIS ----
char str_lits[1000][2048];
int str_lits_len[1000];
int num_str_lits = 0;

int add_string_literal(char *token) {
    char buffer[2048] = "";
    int len = 0;
    for (int i = 1; token[i] != '\0' && i < strlen(token) - 1; i++) {
        if (token[i] == '\\' && token[i+1] == 'n') { strcat(buffer, "\\0A"); i++; len++; } 
        else if (token[i] == '\\' && token[i+1] == 't') { strcat(buffer, "\\09"); i++; len++; } 
        else if (token[i] == '\\' && token[i+1] == '"') { strcat(buffer, "\\22"); i++; len++; } 
        else if (token[i] == '\\' && token[i+1] == '\\') { strcat(buffer, "\\5C"); i++; len++; } 
        else if (token[i] == '\\' && token[i+1] == 'f') { strcat(buffer, "\\0C"); i++; len++; } 
        else if (token[i] == '\\' && token[i+1] == 'r') { strcat(buffer, "\\0D"); i++; len++; } 
        else {
            int blen = strlen(buffer);
            buffer[blen] = token[i];
            buffer[blen+1] = '\0';
            len++;
        }
    }
    strcat(buffer, "\\00"); len++;
    for(int i=0; i<num_str_lits; i++) { if(strcmp(str_lits[i], buffer) == 0) return i; }
    strcpy(str_lits[num_str_lits], buffer);
    str_lits_len[num_str_lits] = len;
    return num_str_lits++;
}

void find_strings(struct node *n) {
    if(!n) return;
    if(n->category == StrLit) add_string_literal(n->token);
    if(n->children) {
        struct node_list *child = n->children->next;
        while(child) { find_strings(child->node); child = child->next; }
    }
}

// ---- TIPOS E CASTS ----
const char* get_llvm_type(char *anot_string) {
    if (anot_string == NULL) return "i32";
    if (strcmp(anot_string, "double") == 0) return "double";
    if (strcmp(anot_string, "boolean") == 0) return "i1";
    if (strcmp(anot_string, "String[]") == 0) return "i8**";
    if (strcmp(anot_string, "void") == 0) return "void";
    return "i32"; 
}

const char* type_to_mangle(const char *type_name) {
    if (strcmp(type_name, "int") == 0) return "int";
    if (strcmp(type_name, "double") == 0) return "double";
    if (strcmp(type_name, "boolean") == 0) return "boolean";
    if (strcmp(type_name, "String[]") == 0) return "StringArray";
    return "undef";
}

void build_mangled_name_from_sig(const char *base, const char *sig, char *out, size_t out_size) {
    if (!sig || strlen(sig) <= 2) {
        snprintf(out, out_size, "_%s_void", base);
        return;
    }

    char sig_copy[1024];
    strncpy(sig_copy, sig, sizeof(sig_copy) - 1);
    sig_copy[sizeof(sig_copy) - 1] = '\0';

    sig_copy[strlen(sig_copy) - 1] = '\0';
    char *types_str = sig_copy + 1;

    snprintf(out, out_size, "_%s", base);
    char *token = strtok(types_str, ",");
    while (token != NULL) {
        const char *m = type_to_mangle(token);
        strncat(out, "_", out_size - strlen(out) - 1);
        strncat(out, m, out_size - strlen(out) - 1);
        token = strtok(NULL, ",");
    }
}

void build_mangled_name_from_params(const char *base, struct node *params, char *out, size_t out_size) {
    if (!params || !params->children || !params->children->next) {
        snprintf(out, out_size, "_%s_void", base);
        return;
    }

    snprintf(out, out_size, "_%s", base);
    struct node_list *curr = params->children->next;
    while (curr) {
        struct node *type_node = get_child(curr->node, 0);
        const char *type_name = "undef";
        if (type_node) {
            if (type_node->category == Int) type_name = "int";
            else if (type_node->category == Double) type_name = "double";
            else if (type_node->category == Bool) type_name = "boolean";
            else if (type_node->category == StringArray) type_name = "String[]";
        }
        const char *m = type_to_mangle(type_name);
        strncat(out, "_", out_size - strlen(out) - 1);
        strncat(out, m, out_size - strlen(out) - 1);
        curr = curr->next;
    }
}

int codegen_expression_and_cast(struct node *expr, const char *target_type) {
    if (expr == NULL) return -1;
    int temp = codegen_expression(expr);
    if (temp == -1) return -1;
    const char *expr_type = get_llvm_type(expr->anot_string);
    if (strcmp(expr_type, "i32") == 0 && strcmp(target_type, "double") == 0) {
        printf("  %%%d = sitofp i32 %%%d to double\n", temporary, temp);
        return temporary++;
    }
    return temp;
}

// ---- EXPRESSÕES BÁSICAS ----
int codegen_natural(struct node *natural) {
    if(natural == NULL || natural->token == NULL) return -1;
    char clean_token[2048]; int j = 0;
    for(int i = 0; natural->token[i] != '\0'; i++) {
        if(natural->token[i] != '_') clean_token[j++] = natural->token[i];
    }
    clean_token[j] = '\0';
    printf("  %%%d = add i32 %s, 0\n", temporary, clean_token);
    return temporary++;
}

int codegen_decimal(struct node *decimal) {
    if(decimal == NULL || decimal->token == NULL) return -1;
    char clean_token[2048]; int j = 0;
    for(int i = 0; decimal->token[i] != '\0'; i++) {
        if(decimal->token[i] != '_') clean_token[j++] = decimal->token[i];
    }
    clean_token[j] = '\0';
    double val = strtod(clean_token, NULL);
    printf("  %%%d = fadd double %.16e, 0.0\n", temporary, val);
    return temporary++;
}

int codegen_boollit(struct node *boollit) {
    int val = (boollit->token != NULL && strcmp(boollit->token, "true") == 0) ? 1 : 0;
    printf("  %%%d = add i1 %d, 0\n", temporary, val);
    return temporary++;
}

int codegen_identifier(struct node *identifier) {
    if(identifier == NULL || identifier->token == NULL) return -1;
    const char *llvm_type = get_llvm_type(identifier->anot_string);
    char *prefix = is_local_variable(identifier->token) ? "%" : "@";
    printf("  %%%d = load %s, %s* %s%s\n", temporary, llvm_type, llvm_type, prefix, identifier->token);
    return temporary++;
}

int codegen_assign(struct node *assign) {
    struct node *id_node = get_child(assign, 0);
    const char *llvm_type = get_llvm_type(id_node->anot_string);
    int rhs_temp = codegen_expression_and_cast(get_child(assign, 1), llvm_type);
    char *prefix = is_local_variable(id_node->token) ? "%" : "@";
    printf("  store %s %%%d, %s* %s%s\n", llvm_type, rhs_temp, llvm_type, prefix, id_node->token);
    return rhs_temp; 
}

int codegen_math(struct node *math_node, const char *int_op, const char *float_op) {
    const char *target_type = get_llvm_type(math_node->anot_string);
    int t1 = codegen_expression_and_cast(get_child(math_node, 0), target_type);
    int t2 = codegen_expression_and_cast(get_child(math_node, 1), target_type);
    if (strcmp(target_type, "double") == 0) printf("  %%%d = %s double %%%d, %%%d\n", temporary, float_op, t1, t2);
    else printf("  %%%d = %s i32 %%%d, %%%d\n", temporary, int_op, t1, t2);
    return temporary++;
}

int codegen_cmp(struct node *cmp) {
    struct node *c1 = get_child(cmp, 0);
    struct node *c2 = get_child(cmp, 1);
    const char *t1_type = get_llvm_type(c1->anot_string);
    const char *t2_type = get_llvm_type(c2->anot_string);

    const char *target_type = "i32";
    if (strcmp(t1_type, "i1") == 0 && strcmp(t2_type, "i1") == 0) target_type = "i1";
    else if (strcmp(t1_type, "double") == 0 || strcmp(t2_type, "double") == 0) target_type = "double";

    int t1 = codegen_expression_and_cast(c1, target_type);
    int t2 = codegen_expression_and_cast(c2, target_type);

    const char *op = "";
    if (strcmp(target_type, "double") == 0) {
        switch(cmp->category) {
            case Eq: op = "oeq"; break; case Ne: op = "one"; break;
            case Lt: op = "olt"; break; case Le: op = "ole"; break;
            case Gt: op = "ogt"; break; case Ge: op = "oge"; break;
            default: break;
        }
        printf("  %%%d = fcmp %s double %%%d, %%%d\n", temporary, op, t1, t2);
    } else {
        switch(cmp->category) {
            case Eq: op = "eq"; break;  case Ne: op = "ne"; break;
            case Lt: op = "slt"; break; case Le: op = "sle"; break;
            case Gt: op = "sgt"; break; case Ge: op = "sge"; break;
            default: break;
        }
        if (strcmp(target_type, "i1") == 0) {
            printf("  %%%d = icmp %s i1 %%%d, %%%d\n", temporary, op, t1, t2);
        } else {
            printf("  %%%d = icmp %s i32 %%%d, %%%d\n", temporary, op, t1, t2);
        }
    }
    return temporary++;
}


int codegen_call(struct node *call) {
    struct node *id_node = get_child(call, 0);
    const char *ret_type = get_llvm_type(call->anot_string);
    char mangled[1024];
    build_mangled_name_from_sig(id_node->token, id_node->anot_string, mangled, sizeof(mangled));
    
    // Ler a assinatura real do método guardada pela Meta 3 no anot_string do Identifier
    char sig[1024] = "";
    if (id_node->anot_string != NULL) strcpy(sig, id_node->anot_string);
    
    const char *target_args_types[20];
    for(int i=0; i<20; i++) target_args_types[i] = "i32"; // Fallback
    
    if (strlen(sig) > 2) {
        sig[strlen(sig)-1] = '\0'; 
        char *types_str = sig + 1; 
        char *token = strtok(types_str, ",");
        int param_c = 0;
        while(token != NULL && param_c < 20) {
            if(strcmp(token, "double") == 0) target_args_types[param_c] = "double";
            else if(strcmp(token, "boolean") == 0) target_args_types[param_c] = "i1";
            else if(strcmp(token, "String[]") == 0) target_args_types[param_c] = "i8**";
            param_c++;
            token = strtok(NULL, ",");
        }
    }

    int args_temps[20]; const char *args_types[20]; int arg_count = 0;
    
    struct node_list *current = call->children->next->next;
    while (current != NULL && arg_count < 20) {
        struct node *arg_expr = current->node;
        const char *t_type = target_args_types[arg_count];
        args_temps[arg_count] = codegen_expression_and_cast(arg_expr, t_type);
        args_types[arg_count] = t_type;
        arg_count++; current = current->next;
    }
    
    if (strcmp(ret_type, "void") == 0) printf("  call void @%s(", mangled);
    else printf("  %%%d = call %s @%s(", temporary, ret_type, mangled);
    
    for (int i = 0; i < arg_count; i++) {
        if (i > 0) printf(", ");
        printf("%s %%%d", args_types[i], args_temps[i]);
    }
    printf(")\n");
    if (strcmp(ret_type, "void") == 0) return 0;
    return temporary++;
}

int codegen_parseargs(struct node *parseargs) {
    struct node *id_node = get_child(parseargs, 0);
    struct node *idx_node = get_child(parseargs, 1);

    int base_ptr = -1;
    if (id_node && id_node->token && strcmp(id_node->token, "args") == 0) {
        base_ptr = temporary++;
        printf("  %%%d = load i8**, i8*** @.args_data\n", base_ptr);
    } else {
        base_ptr = codegen_identifier(id_node);
    }

    int idx_temp = codegen_expression_and_cast(idx_node, "i32");

    int res_ptr = temporary++;
    printf("  %%%d = alloca i32\n", res_ptr);
    printf("  store i32 0, i32* %%%d\n", res_ptr);

    int len_temp = temporary++;
    printf("  %%%d = load i32, i32* @.args_length\n", len_temp);
    int ge_zero = temporary++;
    printf("  %%%d = icmp sge i32 %%%d, 0\n", ge_zero, idx_temp);
    int lt_len = temporary++;
    printf("  %%%d = icmp slt i32 %%%d, %%%d\n", lt_len, idx_temp, len_temp);
    int in_bounds = temporary++;
    printf("  %%%d = and i1 %%%d, %%%d\n", in_bounds, ge_zero, lt_len);

    int l_has = label++;
    int l_end = label++;
    printf("  br i1 %%%d, label %%L%d, label %%L%d\n", in_bounds, l_has, l_end);

    printf("L%d:\n", l_has);
    int gep_temp = temporary++;
    printf("  %%%d = getelementptr inbounds i8*, i8** %%%d, i32 %%%d\n", gep_temp, base_ptr, idx_temp);
    int str_temp = temporary++;
    printf("  %%%d = load i8*, i8** %%%d\n", str_temp, gep_temp);
    int atoi_temp = temporary++;
    printf("  %%%d = call i32 @atoi(i8* %%%d)\n", atoi_temp, str_temp);
    printf("  store i32 %%%d, i32* %%%d\n", atoi_temp, res_ptr);
    printf("  br label %%L%d\n", l_end);

    printf("L%d:\n", l_end);
    int out_temp = temporary++;
    printf("  %%%d = load i32, i32* %%%d\n", out_temp, res_ptr);
    return out_temp;
}

int codegen_length(struct node *length_node) {
    printf("  %%%d = load i32, i32* @.args_length\n", temporary);
    return temporary++;
}

// ---- OPERADORES UNÁRIOS ----
int codegen_minus(struct node *minus_node) {
    struct node *child = get_child(minus_node, 0);
    const char *type = get_llvm_type(minus_node->anot_string);
    int tmp = codegen_expression_and_cast(child, type);
    
    if (strcmp(type, "double") == 0) printf("  %%%d = fsub double -0.0, %%%d\n", temporary, tmp);
    else printf("  %%%d = sub i32 0, %%%d\n", temporary, tmp);
    return temporary++;
}

int codegen_plus(struct node *plus_node) {
    return codegen_expression(get_child(plus_node, 0));
}

int codegen_not(struct node *not_node) {
    int tmp = codegen_expression(get_child(not_node, 0));
    printf("  %%%d = xor i1 %%%d, 1\n", temporary, tmp);
    return temporary++;
}

// ---- OPERADORES LÓGICOS ----
int codegen_and(struct node *and_node) {
    int res_ptr = temporary++;
    printf("  %%%d = alloca i1\n", res_ptr);
    int l_eval_right = label++; int l_end = label++;
    
    int left_val = codegen_expression(get_child(and_node, 0));
    printf("  store i1 %%%d, i1* %%%d\n", left_val, res_ptr); 
    printf("  br i1 %%%d, label %%L%d, label %%L%d\n", left_val, l_eval_right, l_end);
    
    printf("L%d:\n", l_eval_right);
    int right_val = codegen_expression(get_child(and_node, 1));
    printf("  store i1 %%%d, i1* %%%d\n", right_val, res_ptr); 
    printf("  br label %%L%d\n", l_end);
    
    printf("L%d:\n", l_end);
    int final_res = temporary++;
    printf("  %%%d = load i1, i1* %%%d\n", final_res, res_ptr);
    return final_res;
}

int codegen_or(struct node *or_node) {
    int res_ptr = temporary++;
    printf("  %%%d = alloca i1\n", res_ptr);
    int l_eval_right = label++; int l_end = label++;
    
    int left_val = codegen_expression(get_child(or_node, 0));
    printf("  store i1 %%%d, i1* %%%d\n", left_val, res_ptr); 
    printf("  br i1 %%%d, label %%L%d, label %%L%d\n", left_val, l_end, l_eval_right);
    
    printf("L%d:\n", l_eval_right);
    int right_val = codegen_expression(get_child(or_node, 1));
    printf("  store i1 %%%d, i1* %%%d\n", right_val, res_ptr); 
    printf("  br label %%L%d\n", l_end);
    
    printf("L%d:\n", l_end);
    int final_res = temporary++;
    printf("  %%%d = load i1, i1* %%%d\n", final_res, res_ptr);
    return final_res;
}

int codegen_expression(struct node *expression) {
    if(expression == NULL) return -1;
    switch(expression->category) {
        case Natural:    return codegen_natural(expression);
        case Decimal:    return codegen_decimal(expression);
        case BoolLit:    return codegen_boollit(expression);
        case Identifier: return codegen_identifier(expression);
        case Assign:     return codegen_assign(expression);
        case Add:        return codegen_math(expression, "add", "fadd");
        case Sub:        return codegen_math(expression, "sub", "fsub");
        case Mul:        return codegen_math(expression, "mul", "fmul");
        case Div:        return codegen_math(expression, "sdiv", "fdiv");
        case Mod:        return codegen_math(expression, "srem", "frem");
        case Eq: case Ne: case Lt: case Le: case Gt: case Ge: return codegen_cmp(expression);
        case Call:       return codegen_call(expression);
        case ParseArgs:  return codegen_parseargs(expression);
        case Length:     return codegen_length(expression);
        case Minus:      return codegen_minus(expression);
        case Plus:       return codegen_plus(expression);
        case Not:        return codegen_not(expression);
        case And:        return codegen_and(expression);
        case Or:         return codegen_or(expression);
        case Xor: {
            const char *t = get_llvm_type(expression->anot_string);
            int t1 = codegen_expression_and_cast(get_child(expression, 0), t);
            int t2 = codegen_expression_and_cast(get_child(expression, 1), t);
            printf("  %%%d = xor %s %%%d, %%%d\n", temporary, t, t1, t2);
            return temporary++;
        }
        default:         break;
    }
    return -1;
}

// ---- STATEMENTS ----
void codegen_print(struct node *print_node) {
    struct node *expr = get_child(print_node, 0);
    if (expr == NULL) return; 

    if (expr->category == StrLit) {
        int id = add_string_literal(expr->token);
        int len = str_lits_len[id];
        int str_ptr = temporary++;
        printf("  %%%d = getelementptr inbounds [%d x i8], [%d x i8]* @.str.custom.%d, i32 0, i32 0\n", str_ptr, len, len, id);
        printf("  %%%d = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.string, i32 0, i32 0), i8* %%%d)\n", temporary++, str_ptr);
        return; 
    }

    int tmp = codegen_expression(expr);
    const char *llvm_type = get_llvm_type(expr->anot_string);
    
    if (strcmp(llvm_type, "i32") == 0) {
        printf("  %%%d = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([3 x i8], [3 x i8]* @.str.int, i32 0, i32 0), i32 %%%d)\n", temporary++, tmp);
    } 
    else if (strcmp(llvm_type, "double") == 0) {
        printf("  %%%d = call i32 (i8*, ...) @printf(i8* getelementptr inbounds ([6 x i8], [6 x i8]* @.str.double, i32 0, i32 0), double %%%d)\n", temporary++, tmp);
    } 
    else if (strcmp(llvm_type, "i1") == 0) {
        printf("  %%%d = select i1 %%%d, i8* getelementptr inbounds ([5 x i8], [5 x i8]* @.str.true, i32 0, i32 0), i8* getelementptr inbounds ([6 x i8], [6 x i8]* @.str.false, i32 0, i32 0)\n", temporary, tmp);
        int sel_tmp = temporary++;
        printf("  %%%d = call i32 (i8*, ...) @printf(i8* %%%d)\n", temporary++, sel_tmp);
    }
}

void codegen_if(struct node *if_stmt, const char *ret_llvm_type) {
    int l_true = label++; int l_false = label++; int l_end = label++;
    int cond_temp = codegen_expression(get_child(if_stmt, 0));
    
    printf("  br i1 %%%d, label %%L%d, label %%L%d\n", cond_temp, l_true, l_false);
    printf("L%d:\n", l_true);
    codegen_statement(get_child(if_stmt, 1), ret_llvm_type); 
    printf("  br label %%L%d\n", l_end);
    printf("L%d:\n", l_false);
    codegen_statement(get_child(if_stmt, 2), ret_llvm_type);
    printf("  br label %%L%d\n", l_end);
    printf("L%d:\n", l_end);
}

void codegen_while(struct node *while_stmt, const char *ret_llvm_type) {
    int l_cond = label++; int l_body = label++; int l_end = label++;
    
    printf("  br label %%L%d\n", l_cond);
    printf("L%d:\n", l_cond);
    int cond_temp = codegen_expression(get_child(while_stmt, 0));
    printf("  br i1 %%%d, label %%L%d, label %%L%d\n", cond_temp, l_body, l_end);
    printf("L%d:\n", l_body);
    codegen_statement(get_child(while_stmt, 1), ret_llvm_type);
    printf("  br label %%L%d\n", l_cond);
    printf("L%d:\n", l_end);
}

void codegen_statement(struct node *stmt, const char *ret_llvm_type) {
    if (stmt == NULL) return;
    
    if (stmt->category == Block) {
        struct node_list *current = stmt->children->next;
        while(current != NULL) { codegen_statement(current->node, ret_llvm_type); current = current->next; }
    }
    else if (stmt->category == VarDecl) {
        strcpy(local_vars[num_local_vars++], get_child(stmt, 1)->token);
    }
    else if (stmt->category == Assign) codegen_assign(stmt);
    else if (stmt->category == Return) {
        struct node *ret_expr = get_child(stmt, 0);
        if (ret_expr != NULL) {
            int ret_temp = codegen_expression_and_cast(ret_expr, ret_llvm_type);
            printf("  ret %s %%%d\n", ret_llvm_type, ret_temp);
        } else printf("  ret void\n");
        printf("L%d:\n", label++); 
    }
    else if (stmt->category == Print) codegen_print(stmt);
    else if (stmt->category == Call) codegen_call(stmt);
    else if (stmt->category == If) codegen_if(stmt, ret_llvm_type);
    else if (stmt->category == While) codegen_while(stmt, ret_llvm_type);
    else codegen_expression(stmt); 
}

// ---- ESTRUTURA GERAL ----
// CORREÇÃO DO DOUBLEANDINT3 (Assinatura das Funções com tipos dinâmicos)
void codegen_function(struct node *method_decl) {
    temporary = 1; 
    num_local_vars = 0; 
    num_alloced = 0; 
    
    struct node *header = get_child(method_decl, 0);
    struct node *body = get_child(method_decl, 1);
    struct node *params = get_child(header, 2);
    
    if (params && params->children) {
        struct node_list *curr = params->children->next;
        while(curr) {
            strcpy(local_vars[num_local_vars++], get_child(curr->node, 1)->token);
            curr = curr->next;
        }
    }

    struct node *type_node = get_child(header, 0);
    struct node *id_node = get_child(header, 1);
    char mangled[1024];
    build_mangled_name_from_params(id_node->token, params, mangled, sizeof(mangled));
    
    const char *ret_llvm_type = "i32";
    if (type_node->category == Double) ret_llvm_type = "double";
    else if (type_node->category == Bool) ret_llvm_type = "i1";
    else if (type_node->category == Void) ret_llvm_type = "void";
    
    printf("define %s @%s(", ret_llvm_type, mangled);
    if (params && params->children) {
        struct node_list *curr = params->children->next; int first = 1;
        while(curr) {
            if (!first) printf(", ");
            const char *p_type = "i32";
            if (get_child(curr->node, 0)->category == Double) p_type = "double";
            else if (get_child(curr->node, 0)->category == Bool) p_type = "i1";
            else if (get_child(curr->node, 0)->category == StringArray) p_type = "i8**";
            
            printf("%s %%%s_arg", p_type, get_child(curr->node, 1)->token); 
            first = 0; curr = curr->next;
        }
    }
    printf(") {\n");
    
    if (params && params->children) {
        struct node_list *curr = params->children->next;
        while(curr) {
            const char *p_type = "i32";
            if (get_child(curr->node, 0)->category == Double) p_type = "double";
            else if (get_child(curr->node, 0)->category == Bool) p_type = "i1";
            else if (get_child(curr->node, 0)->category == StringArray) p_type = "i8**";

            char *p_name = get_child(curr->node, 1)->token;
            printf("  %%%s = alloca %s\n", p_name, p_type);
            printf("  store %s %%%s_arg, %s* %%%s\n", p_type, p_name, p_type, p_name);
            curr = curr->next;
        }
    }
    
    print_all_allocas(body);
    
    if (body && body->children) {
        struct node_list *current = body->children->next;
        while (current != NULL) {
            codegen_statement(current->node, ret_llvm_type);
            current = current->next;
        }
    }
    
    if (strcmp(ret_llvm_type, "void") == 0) printf("  ret void\n");
    else if (strcmp(ret_llvm_type, "double") == 0) printf("  ret double 0.0\n");
    else if (strcmp(ret_llvm_type, "i1") == 0) printf("  ret i1 0\n");
    else printf("  ret i32 0\n");
    printf("}\n\n");
}

void codegen_program(struct node *program) {
    if (program == NULL || program->children == NULL) return;

    printf("declare i32 @atoi(i8*)\n");
    printf("declare i32 @printf(i8*, ...)\n\n");
    
    printf("@.str.int = private unnamed_addr constant [3 x i8] c\"%%d\\00\"\n");
    printf("@.str.double = private unnamed_addr constant [6 x i8] c\"%%.16e\\00\"\n");
    printf("@.str.true = private unnamed_addr constant [5 x i8] c\"true\\00\"\n");
    printf("@.str.false = private unnamed_addr constant [6 x i8] c\"false\\00\"\n");
    printf("@.str.string = private unnamed_addr constant [3 x i8] c\"%%s\\00\"\n\n");

    printf("@.args_length = global i32 0\n");
    printf("@.args_data = global i8** null\n\n");

    num_str_lits = 0; 
    find_strings(program); 
    for (int i = 0; i < num_str_lits; i++) {
        printf("@.str.custom.%d = private unnamed_addr constant [%d x i8] c\"%s\"\n", i, str_lits_len[i], str_lits[i]);
    }
    printf("\n");

    struct node_list *current_global = program->children->next->next;
    while(current_global != NULL) {
        struct node *decl = current_global->node;
        if (decl->category == FieldDecl) {
            const char *llvm_type = "i32";
            const char *def_val = "0";
            if (get_child(decl, 0)->category == Double) { llvm_type = "double"; def_val = "0.0"; }
            else if (get_child(decl, 0)->category == Bool) { llvm_type = "i1"; def_val = "0"; }
            printf("@%s = global %s %s\n", get_child(decl, 1)->token, llvm_type, def_val);
        }
        current_global = current_global->next;
    }
    printf("\n");

    struct node_list *current = program->children->next->next;
    while(current != NULL) {
        struct node *decl = current->node;
        if (decl->category == MethodDecl) codegen_function(decl);
        current = current->next;
    }

    struct symbol_list *entry = search_symbol(global_table, "main");
    if(entry != NULL && entry->param_types != NULL) {
        struct symbol_list *main_sym = NULL;
        struct symbol_list *curr = global_table->symbols;
        while (curr) {
            if (strcmp(curr->identifier, "main") == 0 && curr->param_types != NULL) {
                if (strcmp(curr->param_types, "(String[])") == 0) { main_sym = curr; break; }
                if (main_sym == NULL) main_sym = curr;
            }
            curr = curr->next;
        }
        if (main_sym == NULL) return;
        entry = main_sym;

        printf("define i32 @main(i32 %%argc, i8** %%argv) {\n");
        printf("  %%argc_len = sub i32 %%argc, 1\n");
        printf("  store i32 %%argc_len, i32* @.args_length\n");
        printf("  %%argv_start = getelementptr inbounds i8*, i8** %%argv, i32 1\n");
        printf("  store i8** %%argv_start, i8*** @.args_data\n");
        
        char main_mangled[1024];
        build_mangled_name_from_sig("main", entry->param_types, main_mangled, sizeof(main_mangled));

        if (strcmp(entry->param_types, "(String[])") == 0) {
            printf("  call void @%s(i8** %%argv_start)\n  ret i32 0\n}\n", main_mangled);
        } else if (strcmp(entry->param_types, "()") == 0) {
            printf("  call void @%s()\n  ret i32 0\n}\n", main_mangled);
        } else {
            printf("  %%1 = icmp sgt i32 %%argc, 1\n");
            printf("  br i1 %%1, label %%has_args, label %%no_args\n");
            printf("has_args:\n");
            printf("  %%2 = getelementptr inbounds i8*, i8** %%argv, i32 1\n");
            printf("  %%3 = load i8*, i8** %%2\n");
            printf("  %%4 = call i32 @atoi(i8* %%3)\n");
            printf("  br label %%call_main\n");
            printf("no_args:\n");
            printf("  br label %%call_main\n");
            printf("call_main:\n");
            printf("  %%5 = phi i32 [ %%4, %%has_args ], [ 0, %%no_args ]\n");
            
            const char *ret_type = "i32";
            if (entry->type == type_double) ret_type = "double";
            else if (entry->type == type_boolean) ret_type = "i1";
            else if (entry->type == type_void) ret_type = "void";

            if (strcmp(ret_type, "void") == 0) {
                printf("  call void @%s(i32 %%5)\n  ret i32 0\n}\n", main_mangled);
            } else if (strcmp(ret_type, "double") == 0) {
                printf("  %%6 = call double @%s(i32 %%5)\n  %%7 = fptosi double %%6 to i32\n  ret i32 %%7\n}\n", main_mangled);
            } else {
                printf("  %%6 = call %s @%s(i32 %%5)\n  ret i32 %%6\n}\n", ret_type, main_mangled);
            }
        }
    }
}
