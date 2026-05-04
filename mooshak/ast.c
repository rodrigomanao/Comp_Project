/*
 * COMP Project
 * Authors: David Pedrosa 2021275573, Rodrigo Manão 2023207589
 */

#include <stdlib.h>
#include <stdio.h>
#include "ast.h"

// categorias de nomes definindas na ast.h
char *category_name[] = names;

//  cria um no dada uma dada categoria de simbolo lexical 
struct node *newnode(enum category category, char *token) {
    struct node *new = malloc(sizeof(struct node));
    new->category = category;
    new->token = token;
    new->anot_string = NULL;
    new->children = malloc(sizeof(struct node_list));
    new->children->node = NULL;
    new->children->next = NULL;
    return new;
}

// adiciona um no a lista de filhos de um no pai
void addchild(struct node *parent, struct node *child) {
    struct node_list *new = malloc(sizeof(struct node_list));
    new->node = child;
    new->next = NULL;
    struct node_list *children = parent->children;
    while(children->next != NULL)
        children = children->next;
    children->next = new;
}

// percorre a AST e imprime o conteudo 
void show(struct node *node, int depth) {
    if (node == NULL) return;
    int i;
    for(i = 0; i < depth; i++) printf("..");

    if(node->token == NULL)
        printf("%s", category_name[node->category]);
    else
        printf("%s(%s)", category_name[node->category], node->token);

    // O truque é imprimir a anotação ANTES do \n
    if (node->anot_string != NULL) {
        printf(" - %s", node->anot_string);
    }
    printf("\n"); // O \n fica sempre no fim

    struct node_list *child = node->children;
    while((child = child->next) != NULL)
        show(child->node, depth+1);
}
