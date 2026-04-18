/* A Bison parser, made by GNU Bison 3.8.2.  */

/* Bison interface for Yacc-like parsers in C

   Copyright (C) 1984, 1989-1990, 2000-2015, 2018-2021 Free Software Foundation,
   Inc.

   This program is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 3 of the License, or
   (at your option) any later version.

   This program is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with this program.  If not, see <https://www.gnu.org/licenses/>.  */

/* As a special exception, you may create a larger work that contains
   part or all of the Bison parser skeleton and distribute that work
   under terms of your choice, so long as that work isn't itself a
   parser generator using the skeleton or a modified version thereof
   as a parser skeleton.  Alternatively, if you modify or redistribute
   the parser skeleton itself, you may (at your option) remove this
   special exception, which will cause the skeleton and the resulting
   Bison output files to be licensed under the GNU General Public
   License without this special exception.

   This special exception was added by the Free Software Foundation in
   version 2.2 of Bison.  */

/* DO NOT RELY ON FEATURES THAT ARE NOT DOCUMENTED in the manual,
   especially those whose name start with YY_ or yy_.  They are
   private implementation details that can be changed or removed.  */

#ifndef YY_YY_Y_TAB_H_INCLUDED
# define YY_YY_Y_TAB_H_INCLUDED
/* Debug traces.  */
#ifndef YYDEBUG
# define YYDEBUG 0
#endif
#if YYDEBUG
extern int yydebug;
#endif

/* Token kinds.  */
#ifndef YYTOKENTYPE
# define YYTOKENTYPE
  enum yytokentype
  {
    YYEMPTY = -2,
    YYEOF = 0,                     /* "end of file"  */
    YYerror = 256,                 /* error  */
    YYUNDEF = 257,                 /* "invalid token"  */
    IDENTIFIER = 258,              /* IDENTIFIER  */
    NATURAL = 259,                 /* NATURAL  */
    DECIMAL = 260,                 /* DECIMAL  */
    STRLIT = 261,                  /* STRLIT  */
    BOOLLIT = 262,                 /* BOOLLIT  */
    BOOL = 263,                    /* BOOL  */
    INT = 264,                     /* INT  */
    DOUBLE = 265,                  /* DOUBLE  */
    STRING = 266,                  /* STRING  */
    VOID = 267,                    /* VOID  */
    CLASS = 268,                   /* CLASS  */
    PUBLIC = 269,                  /* PUBLIC  */
    STATIC = 270,                  /* STATIC  */
    RETURN = 271,                  /* RETURN  */
    IF = 272,                      /* IF  */
    ELSE = 273,                    /* ELSE  */
    WHILE = 274,                   /* WHILE  */
    PRINT = 275,                   /* PRINT  */
    PARSEINT = 276,                /* PARSEINT  */
    DOTLENGTH = 277,               /* DOTLENGTH  */
    PLUS = 278,                    /* PLUS  */
    MINUS = 279,                   /* MINUS  */
    STAR = 280,                    /* STAR  */
    DIV = 281,                     /* DIV  */
    MOD = 282,                     /* MOD  */
    EQ = 283,                      /* EQ  */
    NE = 284,                      /* NE  */
    LT = 285,                      /* LT  */
    LE = 286,                      /* LE  */
    GT = 287,                      /* GT  */
    GE = 288,                      /* GE  */
    AND = 289,                     /* AND  */
    OR = 290,                      /* OR  */
    NOT = 291,                     /* NOT  */
    XOR = 292,                     /* XOR  */
    LSHIFT = 293,                  /* LSHIFT  */
    RSHIFT = 294,                  /* RSHIFT  */
    ASSIGN = 295,                  /* ASSIGN  */
    COMMA = 296,                   /* COMMA  */
    SEMICOLON = 297,               /* SEMICOLON  */
    ARROW = 298,                   /* ARROW  */
    LBRACE = 299,                  /* LBRACE  */
    RBRACE = 300,                  /* RBRACE  */
    LPAR = 301,                    /* LPAR  */
    RPAR = 302,                    /* RPAR  */
    LSQ = 303,                     /* LSQ  */
    RSQ = 304,                     /* RSQ  */
    RESERVED = 305,                /* RESERVED  */
    IFX = 306,                     /* IFX  */
    UMINUS = 307                   /* UMINUS  */
  };
  typedef enum yytokentype yytoken_kind_t;
#endif
/* Token kinds.  */
#define YYEMPTY -2
#define YYEOF 0
#define YYerror 256
#define YYUNDEF 257
#define IDENTIFIER 258
#define NATURAL 259
#define DECIMAL 260
#define STRLIT 261
#define BOOLLIT 262
#define BOOL 263
#define INT 264
#define DOUBLE 265
#define STRING 266
#define VOID 267
#define CLASS 268
#define PUBLIC 269
#define STATIC 270
#define RETURN 271
#define IF 272
#define ELSE 273
#define WHILE 274
#define PRINT 275
#define PARSEINT 276
#define DOTLENGTH 277
#define PLUS 278
#define MINUS 279
#define STAR 280
#define DIV 281
#define MOD 282
#define EQ 283
#define NE 284
#define LT 285
#define LE 286
#define GT 287
#define GE 288
#define AND 289
#define OR 290
#define NOT 291
#define XOR 292
#define LSHIFT 293
#define RSHIFT 294
#define ASSIGN 295
#define COMMA 296
#define SEMICOLON 297
#define ARROW 298
#define LBRACE 299
#define RBRACE 300
#define LPAR 301
#define RPAR 302
#define LSQ 303
#define RSQ 304
#define RESERVED 305
#define IFX 306
#define UMINUS 307

/* Value type.  */
#if ! defined YYSTYPE && ! defined YYSTYPE_IS_DECLARED
union YYSTYPE
{
#line 29 "jucompiler.y"

    char *lexeme;
    struct node *node;

#line 176 "y.tab.h"

};
typedef union YYSTYPE YYSTYPE;
# define YYSTYPE_IS_TRIVIAL 1
# define YYSTYPE_IS_DECLARED 1
#endif


extern YYSTYPE yylval;


int yyparse (void);


#endif /* !YY_YY_Y_TAB_H_INCLUDED  */
