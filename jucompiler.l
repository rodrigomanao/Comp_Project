%{
    /*
        David Pedrosa 2021275573
        Rodrigo Manão 2023207589
    */
    #include <stdio.h> 
    #include <string.h>

    /* place here any C variables and definitions */
    int ncol = 1; // incrementador da coluna
    int nline = 1; // incrementador da linha
    int str_line, str_col; // para guardar a posição inicial da string
    char str_buffer[1024]; // buffer para acumular a string
    int str_pos = 0; // posição do buffer


    // Valor default das flags caso nao tenha flags no input
    int print_tokens = 0; // flag para os prints dos tokens "-l"
    int print_errors = 1; // flag para os prints dos erros "-e1"

    /*
    void append_to_buffer(const char *text) {
        int len = strlen(text);
        while (buffer_size + len >= buffer_capacity) {
            if (buffer_capacity == 0) buffer_capacity = 16;
            else buffer_capacity *= 2;
            buffer = realloc(buffer, buffer_capacity);
        }
        strcpy(buffer + buffer_size, text);
        buffer_size + len;
    }
    */
%}

digit       [0-9]
numpart     {digit}(({digit}|_)*{digit})?
expsign     [+-]
exponent    [eE]{expsign}?{numpart}

reserved    "abstract"|"assert"|"boolean"|"break"|"byte"|"case"|"catch"|"char"|"class"|"const"|"continue"|"default"|"do"|"double"|"else"|"enum"|"extends"|"final"|"finally"|"float"|"for"|"if"|"goto"|"implements"|"import"|"instanceof"|"int"|"interface"|"long"|"native"|"new"|"package"|"private"|"protected"|"public"|"return"|"short"|"static"|"strictfp"|"super"|"switch"|"synchronized"|"this"|"throw"|"throws"|"transient"|"try"|"void"|"volatile"|"while"|"System"|"Integer"|"null"|"++"|"--"
letter      [a-zA-Z_$]
whitespace  [ \t]
newline     [\n\r]

%X BLOCK_COMMENT
%X STRLIT

%%

\"                                      { str_line = nline; str_col = ncol; ncol += yyleng; str_pos = 0; BEGIN(STRLIT); }
<STRLIT>\"                              { ncol += yyleng; str_buffer[str_pos] = '\0'; printf("STRLIT(\"%s\")\n", str_buffer); BEGIN(INITIAL); }
<STRLIT>\\[fnrt\\"']                    { ncol += yyleng; str_buffer[str_pos++] = yytext[0]; str_buffer[str_pos++] = yytext[1]; }
<STRLIT>\\[^fnrt\\"'\n]                 { if(print_errors) printf("Line %d, col %d: invalid escape sequence (%s)\n", nline, ncol, yytext); ncol += yyleng; BEGIN(INITIAL); }
<STRLIT>[\n\r]                          { if(print_errors) printf("Line %d, col %d: unterminated string literal\n", str_line, str_col); ncol = 1; nline++; BEGIN(INITIAL); }
<STRLIT><<EOF>>                         { printf("Line %d col %d: unterminated with end of file\n", str_line, str_col); ncol = 1; nline++; BEGIN(INITIAL); } 
<STRLIT>.                               { ncol += yyleng; str_buffer[str_pos++] = yytext[0]; }


"/*"                                    { BEGIN(BLOCK_COMMENT); }
<BLOCK_COMMENT>"*/"                     { BEGIN(INITIAL); }
<BLOCK_COMMENT>\n                       { ncol=1; nline++; }
<BLOCK_COMMENT>.                        { ncol += yyleng; }


{newline}                               { ; ncol = 1; nline++; }

"true" | "false"                        { if(print_tokens) printf("BOOLLIT\n"); ncol += yyleng; }
"&&"                                    { if(print_tokens) printf("AND\n"); ncol += yyleng; }
"="                                     { if(print_tokens) printf("ASSIGN\n"); ncol += yyleng; }
"*"                                     { if(print_tokens) printf("STAR\n"); ncol += yyleng; }
","                                     { if(print_tokens) printf("COMMA\n"); ncol += yyleng; }
"/"                                     { if(print_tokens) printf("DIV\n"); ncol += yyleng; }
"=="                                    { if(print_tokens) printf("EQ\n"); ncol += yyleng; }
">="                                    { if(print_tokens) printf("GE\n"); ncol += yyleng; }
">"                                     { if(print_tokens) printf("GT\n"); ncol += yyleng; }
"{"                                     { if(print_tokens) printf("LBRACE\n"); ncol += yyleng; }
"<="                                    { if(print_tokens) printf("LE\n"); ncol += yyleng; }
"("                                     { if(print_tokens) printf("LPAR\n"); ncol += yyleng; }
"["                                     { if(print_tokens) printf("LSQ\n"); ncol += yyleng; }
"<"                                     { if(print_tokens) printf("LT\n"); ncol += yyleng; }
"-"                                     { if(print_tokens) printf("MINUS\n"); ncol += yyleng; }
"%"                                     { if(print_tokens) printf("MOD\n"); ncol += yyleng; }
"!="                                    { if(print_tokens) printf("NE\n"); ncol += yyleng; }
"!"                                     { if(print_tokens) printf("NOT\n"); ncol += yyleng; }
"||"                                    { if(print_tokens) printf("OR\n"); ncol += yyleng; }
"+"                                     { if(print_tokens) printf("PLUS\n"); ncol += yyleng; }
"}"                                     { if(print_tokens) printf("RBRACE\n"); ncol += yyleng; }
")"                                     { if(print_tokens) printf("RPAR\n"); ncol += yyleng; }
"]"                                     { if(print_tokens) printf("RSQ\n"); ncol += yyleng; }
";"                                     { if(print_tokens) printf("SEMICOLON\n"); ncol += yyleng; }
"->"                                    { if(print_tokens) printf("ARROW\n"); ncol += yyleng; }
"<<"                                    { if(print_tokens) printf("LSHIFT\n"); ncol += yyleng; }
">>"                                    { if(print_tokens) printf("RSHIFT\n"); ncol += yyleng; }

"boolean"                               { if(print_tokens) printf("BOOL\n"); ncol += yyleng; }
"class"                                 { if(print_tokens) printf("CLASS\n"); ncol += yyleng; }
".length"                               { if(print_tokens) printf("DOTLENGTH\n"); ncol += yyleng; }
"double"                                { if(print_tokens) printf("DOUBLE\n"); ncol += yyleng; }
"else"                                  { if(print_tokens) printf("ELSE\n"); ncol += yyleng; }
"if"                                    { if(print_tokens) printf("IF\n"); ncol += yyleng; }
"int"                                   { if(print_tokens) printf("INT\n"); ncol += yyleng;  }
"System.out.print"                      { if(print_tokens) printf("PRINT\n"); ncol += yyleng; }
"Integer.parseInt"                      { if(print_tokens) printf("PARSEINT\n"); ncol += yyleng; }
"public"                                { if(print_tokens) printf("PUBLIC\n"); ncol += yyleng; }
"return"                                { if(print_tokens) printf("RETURN\n"); ncol += yyleng; }
"static"                                { if(print_tokens) printf("STATIC\n"); ncol += yyleng; }
"String"                                { if(print_tokens) printf("STRING\n"); ncol += yyleng; }
"void"                                  { if(print_tokens) printf("VOID\n"); ncol += yyleng; }
"while"                                 { if(print_tokens) printf("WHILE\n"); ncol += yyleng; }

{reserved}                              { if(print_tokens) printf("RESERVED(%s)\n", yytext); ncol += yyleng; }





"0"|[1-9](({digit}|_)*{digit})?         { if(print_tokens) printf("NATURAL(%s)\n", yytext); ncol += yyleng; }
{numpart}"."{numpart}?{exponent}?|"."{numpart}{exponent}?|{numpart}{exponent}                  { if(print_tokens) printf("DECIMAL(%s)\n", yytext); ncol += yyleng; }
{letter}({digit}|{letter})*             { if(print_tokens) printf("IDENTIFIER(%s)\n", yytext); ncol += yyleng; }
{whitespace}                            { ; ncol += yyleng; }

.                                       { printf("Line %d, col %d: illegal character (%s)\n", nline, ncol, yytext ); ncol += yyleng;}

%%


extern int yylex();

int main(int argc, char **argv) {
    
    if (argc >1){
        if(strcmp(argv[1], "-l") == 0){ // Para imprimir tokens
            print_tokens = 1;
            print_errors = 1;
        }
        else if(strcmp(argv[1], "-e1") == 0){ // Para imprimir apneas os erros
            print_tokens = 0;
            print_errors = 1;
        }
        else{
            fprintf(stderr, "Unknown option: %s\n", argv[1]);
            return 1;
        }

    }
    
    yylex();    /* run the lexical analysis automaton */
    return 0;
}
int yywrap() {  /* called on EOF, return 1 to terminate */
    return 1;
}