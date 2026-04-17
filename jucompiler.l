%{
    /*
        David Pedrosa 2021275573
        Rodrigo Manão 2023207589
    */
    #include <stdio.h>
    #include <string.h>
    #include <stdlib.h>
    
    #include "y.tab.h"

    #define PASS_TOKEN() yylval.lexeme = strdup(yytext);
    #define PASS_TOKEN_STR() yylval.lexeme = strdup(buffer);


    int yyparse(void);
    void yyerror (char *s);

    int ncol = 1;
    int nline = 1;
    int str_line, str_col;
    int str_pos = 0;

    int begin_col_block = 1;
    int begin_line_block = 1;

    int print_tokens = 0;
    int print_errors = 1;
    int valid_string = 1;

    // Buffer dinâmico para acumular a string
    char *buffer = NULL;
    int buffer_size = 0;
    int buffer_capacity = 0;

    // Para fazer a limpeza das mensagens de erro do tipo "\a(\n real)", que metiam o parenteses em baixo e
    char *clean_str(char *s) {
        static char buffer[256]; 
        int j = 0;
        for (int i = 0; s[i] != '\0' && j < 255; i++) {
            if (s[i] != '\n' && s[i] != '\r') {
                buffer[j++] = s[i];
            }
        }
        buffer[j] = '\0';
        return buffer;
    }

    void append_to_buffer(const char *text) {
        int len = strlen(text);
        while (buffer_size + len + 1 > buffer_capacity) {
            if (buffer_capacity == 0) buffer_capacity = 16;
            else buffer_capacity *= 2;
            buffer = realloc(buffer, buffer_capacity);
        }
        strcpy(buffer + buffer_size, text);
        buffer_size += len;
    }

    void reset_buffer() {
        buffer_size = 0;
        if (buffer_capacity == 0) {
            buffer_capacity = 16;
            buffer = malloc(buffer_capacity);
        }
        buffer[0] = '\0';
    }

%}

digit       [0-9]
numpart     {digit}(({digit}|_)*{digit})?
expsign     [+-]
exponent    [eE]{expsign}?{numpart}

reserved    "abstract"|"assert"|"break"|"byte"|"case"|"catch"|"char"|"const"|"continue"|"default"|"do"|"enum"|"extends"|"final"|"finally"|"float"|"for"|"goto"|"implements"|"import"|"instanceof"|"interface"|"long"|"native"|"new"|"package"|"private"|"protected"|"short"|"strictfp"|"super"|"switch"|"synchronized"|"this"|"throw"|"throws"|"transient"|"try"|"volatile"|"System"|"Integer"|"null"|"++"|"--"

letter      [a-zA-Z_$]
whitespace  [ \t\f]
newline     "\r\n"|"\n"|"\r"

%X STRLIT
%X BLOCK_COMMENT
%X SINGLE_COMMENT

%%

\"                              { str_line = nline; str_col = ncol; ncol += yyleng; reset_buffer(); valid_string = 1; BEGIN(STRLIT); }
<STRLIT>\"                      { ncol += yyleng; if(print_tokens && valid_string) printf("STRLIT(\"%s\")\n", buffer); BEGIN(INITIAL); PASS_TOKEN_STR(); return STRLIT; }
<STRLIT>\\[fnrt\\"]             { ncol += yyleng; append_to_buffer(yytext); }
<STRLIT>\\{newline}             { if(print_errors){ 
                                            printf("Line %d, col %d: invalid escape sequence (%s)\n", nline, ncol, clean_str(yytext)); valid_string = 0; ncol += yyleng; }
                                            printf("Line %d, col %d: unterminated string literal\n", str_line, str_col); ncol = 1; nline++; BEGIN(INITIAL); }
                                            
<STRLIT>\\                      { if(print_errors) printf("Line %d, col %d: unterminated string literal\n", str_line, str_col); valid_string = 0; BEGIN(INITIAL); }
<STRLIT>{newline}               { if(print_errors) printf("Line %d, col %d: unterminated string literal\n", str_line, str_col); valid_string = 0; ncol = 1; nline++; BEGIN(INITIAL); }
<STRLIT><<EOF>>                 { if(print_errors) printf("Line %d, col %d: unterminated string literal\n", str_line, str_col); BEGIN(INITIAL); }
<STRLIT>.                       { ncol += yyleng; append_to_buffer(yytext); }
<STRLIT>\\.                     { if(print_errors) printf("Line %d, col %d: invalid escape sequence (%s)\n", nline, ncol, clean_str(yytext)); valid_string = 0; ncol += yyleng; }


"/*"                            { begin_line_block = nline; begin_col_block = ncol; ncol += yyleng; BEGIN(BLOCK_COMMENT); }
<BLOCK_COMMENT>"*/"             { ncol += yyleng; BEGIN(INITIAL); }
<BLOCK_COMMENT>{newline}        { nline++; ncol = 1; }
<BLOCK_COMMENT><<EOF>>          { printf("Line %d, col %d: unterminated comment\n", begin_line_block, begin_col_block); ncol = 1; BEGIN(INITIAL); }
<BLOCK_COMMENT>.                { ncol += yyleng; }

"//"                            { BEGIN(SINGLE_COMMENT); }
<SINGLE_COMMENT>{newline}       { ncol = 1; nline++; BEGIN(INITIAL); }
<SINGLE_COMMENT><<EOF>>         { BEGIN(INITIAL); }
<SINGLE_COMMENT>.               { ; }


{newline}                       { ncol = 1; nline++; }

"true"|"false"                  { if(print_tokens) printf("BOOLLIT(%s)\n", yytext); ncol += yyleng; PASS_TOKEN(); return BOOLLIT; }
"&&"                            { if(print_tokens) printf("AND\n"); ncol += yyleng; return AND; }
"^"                             { if(print_tokens) printf("XOR\n"); ncol += yyleng; return XOR; }
"="                             { if(print_tokens) printf("ASSIGN\n"); ncol += yyleng; return ASSIGN; }
"*"                             { if(print_tokens) printf("STAR\n"); ncol += yyleng; return STAR; }
","                             { if(print_tokens) printf("COMMA\n"); ncol += yyleng; return COMMA; }
"/"                             { if(print_tokens) printf("DIV\n"); ncol += yyleng; return DIV; }
"=="                            { if(print_tokens) printf("EQ\n"); ncol += yyleng; return EQ; }
">="                            { if(print_tokens) printf("GE\n"); ncol += yyleng; return GE; }
">"                             { if(print_tokens) printf("GT\n"); ncol += yyleng; return GT; }
"{"                             { if(print_tokens) printf("LBRACE\n"); ncol += yyleng; return LBRACE; }
"<="                            { if(print_tokens) printf("LE\n"); ncol += yyleng; return LE; }
"("                             { if(print_tokens) printf("LPAR\n"); ncol += yyleng; return LPAR; }
"["                             { if(print_tokens) printf("LSQ\n"); ncol += yyleng; return LSQ; }
"<"                             { if(print_tokens) printf("LT\n"); ncol += yyleng; return LT; }
"-"                             { if(print_tokens) printf("MINUS\n"); ncol += yyleng; return MINUS; }
"%"                             { if(print_tokens) printf("MOD\n"); ncol += yyleng; return MOD; }
"!="                            { if(print_tokens) printf("NE\n"); ncol += yyleng; return NE; }
"!"                             { if(print_tokens) printf("NOT\n"); ncol += yyleng; return NOT; }
"||"                            { if(print_tokens) printf("OR\n"); ncol += yyleng; return OR; }
"+"                             { if(print_tokens) printf("PLUS\n"); ncol += yyleng; return PLUS; }
"}"                             { if(print_tokens) printf("RBRACE\n"); ncol += yyleng; return RBRACE; }
")"                             { if(print_tokens) printf("RPAR\n"); ncol += yyleng; return RPAR; }
"]"                             { if(print_tokens) printf("RSQ\n"); ncol += yyleng; return RSQ; }
";"                             { if(print_tokens) printf("SEMICOLON\n"); ncol += yyleng; return SEMICOLON; }
"->"                            { if(print_tokens) printf("ARROW\n"); ncol += yyleng; return ARROW; }
"<<"                            { if(print_tokens) printf("LSHIFT\n"); ncol += yyleng; return LSHIFT; }
">>"                            { if(print_tokens) printf("RSHIFT\n"); ncol += yyleng; return RSHIFT; }

"boolean"                       { if(print_tokens) printf("BOOL\n"); ncol += yyleng; return BOOL; }
"class"                         { if(print_tokens) printf("CLASS\n"); ncol += yyleng; return CLASS; }
".length"                       { if(print_tokens) printf("DOTLENGTH\n"); ncol += yyleng; return DOTLENGTH; }
"double"                        { if(print_tokens) printf("DOUBLE\n"); ncol += yyleng; return DOUBLE; }
"else"                          { if(print_tokens) printf("ELSE\n"); ncol += yyleng; return ELSE; }
"if"                            { if(print_tokens) printf("IF\n"); ncol += yyleng;return IF; }
"int"                           { if(print_tokens) printf("INT\n"); ncol += yyleng; return INT; }
"System.out.print"              { if(print_tokens) printf("PRINT\n"); ncol += yyleng; return PRINT; }
"Integer.parseInt"              { if(print_tokens) printf("PARSEINT\n"); ncol += yyleng; return PARSEINT; }
"public"                        { if(print_tokens) printf("PUBLIC\n"); ncol += yyleng; return PUBLIC; }
"return"                        { if(print_tokens) printf("RETURN\n"); ncol += yyleng; return RETURN; }
"static"                        { if(print_tokens) printf("STATIC\n"); ncol += yyleng; return STATIC; }
"String"                        { if(print_tokens) printf("STRING\n"); ncol += yyleng; return STRING; }
"void"                          { if(print_tokens) printf("VOID\n"); ncol += yyleng; return VOID; }
"while"                         { if(print_tokens) printf("WHILE\n"); ncol += yyleng; return WHILE; }

{reserved}                      { if(print_tokens) printf("RESERVED(%s)\n", yytext); ncol += yyleng; return RESERVED; }

"0"|[1-9](({digit}|_)*{digit})?                                                { if(print_tokens) printf("NATURAL(%s)\n", yytext); ncol += yyleng; PASS_TOKEN(); return NATURAL; }
{numpart}"."{numpart}?{exponent}?|"."{numpart}{exponent}?|{numpart}{exponent}  { if(print_tokens) printf("DECIMAL(%s)\n", yytext); ncol += yyleng; PASS_TOKEN(); return DECIMAL; }
{letter}({digit}|{letter})*     { if(print_tokens) printf("IDENTIFIER(%s)\n", yytext); ncol += yyleng; PASS_TOKEN(); return IDENTIFIER; }
{whitespace}                    { ncol += yyleng; }

.                               { printf("Line %d, col %d: illegal character (%s)\n", nline, ncol, yytext); ncol += yyleng; }

%%

int main(int argc, char **argv) {
    int print_tree = 0; // Flag para a AST (futuro)
    
    if (argc > 1) {
        if (strcmp(argv[1], "-l") == 0) {
            print_tokens = 1; 
            print_errors = 1;
        } else if (strcmp(argv[1], "-e1") == 0) {
            print_tokens = 0; 
            print_errors = 1;
        } else if (strcmp(argv[1], "-e2") == 0) {
            print_tokens = 0; 
            print_errors = 1;
        } else if (strcmp(argv[1], "-t") == 0) {
            print_tokens = 0; 
            print_errors = 1; 
            print_tree = 1;
        } else {
            print_tokens = 0; 
            print_errors = 1;
        }
    }

    yyparse();
    
    free(buffer);
    return 0;
}

int yywrap() {
    return 1;
}

void yyerror (char *s) {
    printf("Line %d, col %d: %s: %s\n", nline, (int)(ncol - strlen(yytext)), s, yytext);
}