%{
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include "stack.h"

/*flex/lex dependencies*/
extern FILE *yyin ;
extern int yylex() ;
extern int yyparse() ;

LIST *Stack_top[1000] ;

#define MAX_BUFFER_LEN	1024

struct arrayInfo {
  char arrayType[MAX_BUFFER_LEN] ;
  int arrayLowerBound ;		//Bounds if the type is an array
  int arrayUpperBound ;		//Bounds if the type is an array
};
struct variableList {
  char variableName[MAX_BUFFER_LEN] ;
  char variableType[MAX_BUFFER_LEN] ;
  int flagDuplicateVariable ;
  //struct arrayInfo arrayInfo ;
} ;

int numTypes = 0 ;
struct typeList {
  char aliasType[MAX_BUFFER_LEN] ;
  char actualType[MAX_BUFFER_LEN] ;
  struct arrayInfo typeArrayInfo ;
  int flagDuplicateType ;
  int numSubVariables ;
  struct variableList subRecordVariables[100] ;	//Sub-fields of the record if the given type is a record
} typesList[1000] ;

int numAssignmentTerms = 0 ;
struct assignmentExpressionTerms {
  char types[MAX_BUFFER_LEN] ;
  char name[MAX_BUFFER_LEN] ;
  char actualType[MAX_BUFFER_LEN] ;
  int flagFunction ;
} assignmentExprTerms[100] ;

#define GLOBAL_SCOPE  1
#define FUNCTIONAL_SCOPE 2
#define PROCEDURAL_SCOPE 3

#define GLOBAL_SUBPROGRAM  0

int flagGlobalScope = 1 ;
int flagAssignmentInvalid = 0 ;
int currentSubProgram = 1 ;
int labelNo = 1 ;
int currentStackNo = 0 ;
int termNo = 0 ;
struct subprogramList {
  int scopeType ;
  char name[1000] ;			//Name if its a function/procedure
  struct variableList subProgramVariableList[100] ;
  char returnType[MAX_BUFFER_LEN] ;
  int numVar ;
} subProgram[1000];

void checkDuplicateSubRecords() ;
void addRecordFieldsType(char *type) ;
void checkDuplicateTypes() ;
void checkDuplicateVariables() ;
void assignVariableType(char *type, int subProgramNo) ;
void addType() ;
int checkSubRecordExists(char *recordName, char *subRecordName) ;
int assignmentLHSDefined(char *variableName) ;
int isVariableDefined(char *variableName) ;
void getActualType(char *aliasType, char *actualType, int *typeIndex) ;
void yyerror(const char *s) ;
void logICG(char *log_desc) ;
%}

%nonassoc LOWER_THAN_ELSE
%union {
  int ival ;
  char *sval ;
}

%token <ival> SEQUENCE_DIGITS
%token <sval> RECORD
%token <sval> IDENTIFIER
%token <sval> STRING
%token <sval> TRUE_BOOLEAN
%token <sval> FALSE_BOOLEAN
%token <sval> ARRAY


%token AND ASSIGNMENT CASE COLON COMMA CONST
%token DIV DO DOT DOUBLEDOT DOWNTO ELSE END EQUAL EXTERNAL FOR FORWARD FUNCTION
%token GE GOTO GT IF IN LABEL LBRACKET LE LPARENTHESIS LT MINUS MOD NIL NOT
%token NOTEQUAL OF OR OTHERWISE PACKED _BEGIN PLUS PROCEDURE PROGRAM RBRACKET
%token FLOATING_POINT REPEAT RPARENTHESIS SEMICOLON SET SLASH STAR DOUBLESTAR THEN
%token TO TYPE UNTIL VAR WHILE UPARROW

%%
Program : PROGRAM IDENTIFIER SEMICOLON Type_Definitions Variable_Declarations SubprogramDeclarations compound_statement DOT |PROGRAM IDENTIFIER SEMICOLON compound_statement DOT ;

Type_Definitions : TYPE Type_Definition_List { checkDuplicateTypes() ;}| ;

Type_Definition_List : Type_Definition_List type_definition
 | type_definition ;

type_definition : IDENTIFIER EQUAL Type SEMICOLON { addType($1) ;
		                                  } ;
Variable_Declarations : VAR variable_declaration_list SEMICOLON {
		      checkDuplicateVariables() ;
		    }| {
		    };

variable_declaration_list : variable_declaration_list SEMICOLON variable_declaration | variable_declaration ;

variable_declaration : VARIABLE_IDENTIFIER_LIST COLON IDENTIFIER {
		             if(flagGlobalScope == 1) {
		               assignVariableType($3, GLOBAL_SUBPROGRAM) ; 
                             }
                             else {
                               assignVariableType($3, currentSubProgram) ;
                             }
                           };

VARIABLE_IDENTIFIER_LIST : VARIABLE_IDENTIFIER_LIST COMMA IDENTIFIER {
			 int subProgramNum ;
                         if(flagGlobalScope == 1) {
                            subProgramNum = GLOBAL_SUBPROGRAM ; 
                         }
                         else {
                            subProgramNum = currentSubProgram ;
                         }
			 int numVar = subProgram[subProgramNum].numVar ; 
			 strcpy(subProgram[subProgramNum].subProgramVariableList[numVar].variableName, $3) ;
                         subProgram[subProgramNum].numVar++ ;
                      } 
                      | IDENTIFIER {
			 int subProgramNum ;
                         if(flagGlobalScope == 1) {
                            subProgramNum = GLOBAL_SUBPROGRAM ; 
                         }
                         else {
                            subProgramNum = currentSubProgram ;
                         }
			 int numVar = subProgram[subProgramNum].numVar ; 
                         strcpy(subProgram[subProgramNum].subProgramVariableList[numVar].variableName, $1) ;
                         subProgram[subProgramNum].numVar++ ;
                      } ;

SubprogramDeclarations : procedure_and_function_declaration_part ;

procedure_and_function_declaration_part :procedure_or_function_declaration_list SEMICOLON |;

procedure_or_function_declaration_list : procedure_or_function_declaration_list SEMICOLON procedure_or_function_declaration | procedure_or_function_declaration ;

procedure_or_function_declaration : procedure_declaration | function_declaration ;

procedure_declaration : procedure_heading SEMICOLON FORWARD  { flagGlobalScope = 1 ;
		          currentSubProgram++ ;
                          //printf("Stack status %d\n", check_stack_empty(&Stack_top[currentStackNo])) ;
                          currentStackNo-- ;
		      }
		      | procedure_heading SEMICOLON procedure_block { flagGlobalScope = 1 ;
		          currentSubProgram++ ;
                          //printf("Stack status %d\n", check_stack_empty(&Stack_top[currentStackNo])) ;
                          currentStackNo-- ;
                      };

procedure_block : block {
                    char log_desc[MAX_BUFFER_LEN] ;
                    sprintf(log_desc, "return\n\n") ;
                    logICG(log_desc) ;
                  };
procedure_heading : PROCEDURE IDENTIFIER formal_parameter_list {
                          flagGlobalScope = 0 ;
                          subProgram[currentSubProgram].scopeType = PROCEDURAL_SCOPE ;
                          strcpy(subProgram[currentSubProgram].name, $2) ;
                          checkDuplicateVariables() ;
                          currentStackNo++ ;
                  };

function_declaration : function_heading SEMICOLON FORWARD {
		                                     flagGlobalScope = 1 ;

                                                     currentSubProgram++ ;
                                                     //printf("Stack status %d\n", check_stack_empty(&Stack_top[currentStackNo])) ;
                                                     currentStackNo-- ;
                                                }
                      | 
                      function_heading SEMICOLON function_block {
                                                                flagGlobalScope = 1 ;

                                                                currentSubProgram++ ;
                                                                //printf("Stack status %d\n", check_stack_empty(&Stack_top[currentStackNo])) ;
                                                                currentStackNo-- ;
                                                    } ;

function_heading : FUNCTION IDENTIFIER formal_parameter_list COLON result_type {
                          flagGlobalScope = 0 ;
                          subProgram[currentSubProgram].scopeType = FUNCTIONAL_SCOPE ;
                          strcpy(subProgram[currentSubProgram].name, $2) ;
                          checkDuplicateVariables() ;
                          currentStackNo++ ;

                       } ;
function_block : block {
	 	        char log_desc[MAX_BUFFER_LEN] ;
		        sprintf(log_desc, "\n\n", subProgram[currentSubProgram].name) ;
                        logICG(log_desc) ;
                 };

result_type : IDENTIFIER {
                           strcpy(subProgram[currentSubProgram].returnType, $1) ;
                           if(strcmp(subProgram[currentSubProgram].returnType, "integer") == 0 || strcmp(subProgram[currentSubProgram].returnType, "boolean") == 0 || strcmp(subProgram[currentSubProgram].returnType, "string") == 0 ) ;
                           else {
                             int  i = 0 ;
                             for(i = 0; i < numTypes; i++) {
                               if(strcmp(typesList[i].aliasType, $1) == 0) {
                                 break ;
                               }
                             }
                             if(i == numTypes) {
                               printf("<error> return type %s of function %s isn't defined\n", $1, subProgram[currentSubProgram].name) ;
                             }
                           }
                         };

formal_parameter_list : LPARENTHESIS formal_parameter_section_list RPARENTHESIS {
                     } ;

formal_parameter_section_list : formal_parameter_section_list SEMICOLON formal_parameter_section
 | formal_parameter_section ;

formal_parameter_section : FORMAL_PARAMETER_IDENTIFIER_LIST COLON IDENTIFIER { assignVariableType($3, currentSubProgram) ; } ;
FORMAL_PARAMETER_IDENTIFIER_LIST :FORMAL_PARAMETER_IDENTIFIER_LIST COMMA IDENTIFIER {
			 int numVar = subProgram[currentSubProgram].numVar ; 
			 strcpy(subProgram[currentSubProgram].subProgramVariableList[numVar].variableName, $3) ;
                         subProgram[currentSubProgram].numVar++ ;
                      } 
                      | IDENTIFIER {
			 int numVar = subProgram[currentSubProgram].numVar ; 
                         strcpy(subProgram[currentSubProgram].subProgramVariableList[numVar].variableName, $1) ;
                         subProgram[currentSubProgram].numVar++ ;
                      } ;


block : Variable_Declarations compound_statement ;

statement : SimpleStatement {} | StructuredStatement ;
SimpleStatement : assignment_statement | procedure_statement | {};
compound_statement : begin statement_sequence END { 
                   //printf("Stack status %d\n", check_stack_empty(&Stack_top[currentStackNo])) ;
		   currentStackNo-- ;};
begin : _BEGIN { currentStackNo++;
               } ;

statement_sequence : statement_sequence SEMICOLON statement  {} | statement {} ;

assignment_statement : assignment_variable_access ASSIGNMENT assignment_expression {
                          char lhsType[MAX_BUFFER_LEN] ;
                          int lhsTypeIndex = -1 ;
                          if(flagAssignmentInvalid == 0) {
			    getActualType(assignmentExprTerms[0].types, lhsType, &lhsTypeIndex) ;
                         
			    int i, typeIndex ;
			    for(i = 1; i < numAssignmentTerms; i++) {
			      getActualType(assignmentExprTerms[i].types, assignmentExprTerms[i].actualType, &typeIndex) ;
			      if((typeIndex == lhsTypeIndex ) && lhsTypeIndex != -1) {
                                //lhs and rhs point to same type
                              }
                              else if (strcmp(lhsType, assignmentExprTerms[i].actualType) != 0) {
				if(flagGlobalScope == 1) {
				  printf("<error> Assignment expression type mismatch in global scope with variable %s\n", assignmentExprTerms[0].name) ;
				}
				else if(subProgram[currentSubProgram].scopeType == FUNCTIONAL_SCOPE) {
				  printf("<error> Assignment expression type mismatch in function %s with variable %s %s %s\n", subProgram[currentSubProgram].name, assignmentExprTerms[0].name, lhsType, assignmentExprTerms[i].actualType) ;
				}
				else if(subProgram[currentSubProgram].scopeType == PROCEDURAL_SCOPE) {
				  printf("<error> Assignment expression type mismatch in procedure %s with variable %s\n", subProgram[currentSubProgram].name, assignmentExprTerms[0].name) ;
				}
				break ;
			      }
			    }
			  }
                          else {
                            printf("<error> Assignment expression is not valid due to missing variable/function definition\n") ;
                            flagAssignmentInvalid = 0 ;
                          }
                          char previousTerm1[MAX_BUFFER_LEN], previousTerm2[MAX_BUFFER_LEN] ;
                          stkpop(&Stack_top[currentStackNo], previousTerm2, MAX_BUFFER_LEN) ;
                          stkpop(&Stack_top[currentStackNo], previousTerm1, MAX_BUFFER_LEN) ;
                          //printf("Assignment terms %s %s\n", previousTerm1, previousTerm2) ;
                          char log_desc[MAX_BUFFER_LEN] ;

                          if(assignmentExprTerms[0].flagFunction == 1) {
                            sprintf(log_desc, "funreturn %s\n", previousTerm2) ;
                          }
                          else {
                            sprintf(log_desc, "%s := %s\n", previousTerm1, previousTerm2) ;
                          }
                          logICG(log_desc) ;

                          numAssignmentTerms = 0 ;
                          memset(assignmentExprTerms, 0, sizeof(struct assignmentExpressionTerms) * 100) ;
                       };

procedure_statement : IDENTIFIER params {
                                    int i ;
                                    for(i = 0; i < currentSubProgram; i++) {
                                       if(strcmp(subProgram[i].name, $1) == 0) {
                                         break ;
                                       }
                                    }
                                    if(i == currentSubProgram) {
                                      printf("<error> undefined reference to function/procedure %s\n", $1) ;
                                    }
                                    char log_desc[MAX_BUFFER_LEN] ;
                                    sprintf(log_desc, "call %s()\n", $1) ;
                                    logICG(log_desc) ;
                                 }; 

params : LPARENTHESIS actual_parameter_list RPARENTHESIS ;
actual_parameter_list : actual_parameter_list COMMA expression {
                        }| expression {
				char previousTerm[MAX_BUFFER_LEN]  ;
                                char log_desc[MAX_BUFFER_LEN] ;
				stkpop(&Stack_top[currentStackNo], previousTerm, MAX_BUFFER_LEN) ;
				sprintf(log_desc, "param %s\n", previousTerm) ;
                                logICG(log_desc) ;
                        } | ;

StructuredStatement : compound_statement {} |
                    if_block else_block {
                       //printf("Stack status %d\n", check_stack_empty(&Stack_top[currentStackNo])) ;
                       char log_desc[MAX_BUFFER_LEN] ;
                       sprintf(log_desc, "end_if_else_L%d:\n", labelNo-1) ;
                       logICG(log_desc) ;
                       labelNo-- ;
                       currentStackNo-- ;
                  }
                | while_ DO statement {
                    char log_desc[MAX_BUFFER_LEN] ;
                    char previousTerm[MAX_BUFFER_LEN] ;
                    stkpop(&Stack_top[currentStackNo], previousTerm, MAX_BUFFER_LEN) ;
                    sprintf(log_desc,"%s\n", previousTerm) ;
                    logICG(log_desc) ;
                    sprintf(log_desc,"end_loop_L%d:\n", labelNo-1) ;
                    logICG(log_desc) ;
                    //printf("Stack status %d\n", check_stack_empty(&Stack_top[currentStackNo])) ;
                    currentStackNo-- ;
                    labelNo-- ;
                  }
                  | for_ DO statement {
                    char previousTerm1[MAX_BUFFER_LEN], previousTerm2[MAX_BUFFER_LEN] ;
                    stkpop(&Stack_top[currentStackNo], previousTerm2, MAX_BUFFER_LEN ) ;
                    stkpop(&Stack_top[currentStackNo], previousTerm1, MAX_BUFFER_LEN ) ;
                    char log_desc[MAX_BUFFER_LEN] ;
                    sprintf(log_desc, "%s\n", previousTerm1) ;
                    logICG(log_desc) ;
                    sprintf(log_desc, "%s\n", previousTerm2) ;
                    logICG(log_desc) ;
                    sprintf(log_desc, "end_loop_L%d:\n", labelNo-1) ;
                    logICG(log_desc) ;
                    //printf("Stack status %d\n", check_stack_empty(&Stack_top[currentStackNo])) ;
                    currentStackNo-- ;
                    labelNo-- ;
                  };
if_block : if_ if_then_expression statement {
         char log_desc[MAX_BUFFER_LEN] ;
         sprintf(log_desc, "goto end_if_else_L%d\n", labelNo-1) ;
         logICG(log_desc) ;
         sprintf(log_desc, "else_L%d:\n", labelNo-1) ;
         logICG(log_desc) ;
} ;
else_block : ELSE statement | ;
if_ : IF {
    currentStackNo++ ;
} ;

if_then_expression : expression THEN {
    char previousTerm[MAX_BUFFER_LEN], log_desc[MAX_BUFFER_LEN] ;
    stkpop(&Stack_top[currentStackNo], previousTerm, MAX_BUFFER_LEN) ;
    sprintf(log_desc, "if %s then goto L%d\n", previousTerm, labelNo) ;
    logICG(log_desc) ;
    sprintf(log_desc, "t%d := %s\n", termNo++, previousTerm) ;
    logICG(log_desc) ;
    sprintf(log_desc, "t%d := not t%d\n", termNo, termNo-1) ;
    logICG(log_desc) ;
    sprintf(log_desc, "if (t%d) then goto else_L%d\n", termNo++, labelNo) ;
    logICG(log_desc) ;
    sprintf(log_desc, "L%d:\n", labelNo) ;
    logICG(log_desc) ;
    labelNo++ ;
}
for_ : for__ IDENTIFIER ASSIGNMENT expression TO expression {
    char log_desc[MAX_BUFFER_LEN] ;
    char previousTerm1[MAX_BUFFER_LEN], previousTerm2[MAX_BUFFER_LEN], currentTerm[MAX_BUFFER_LEN] ;
    stkpop(&Stack_top[currentStackNo], previousTerm2, MAX_BUFFER_LEN) ;
    stkpop(&Stack_top[currentStackNo], previousTerm1, MAX_BUFFER_LEN) ;
    sprintf(log_desc,"%s := %s\n", $2, previousTerm1) ;
    logICG(log_desc) ;
    sprintf(log_desc,"if (%s > %s) then goto end_loop_L%d\n", $2, previousTerm2, labelNo ) ;
    logICG(log_desc) ;
    sprintf(log_desc,"loop_L%d:\n", labelNo) ;
    logICG(log_desc) ;
    labelNo++ ;
    sprintf(currentTerm,"%s := %s + 1", $2, $2) ;
    stkpush(&Stack_top[currentStackNo], currentTerm) ;
    sprintf(currentTerm,"if ( %s <= %s) then goto loop_L%d", $2, previousTerm2, labelNo-1) ;
    stkpush(&Stack_top[currentStackNo], currentTerm) ;
     };
for__ : FOR {
        currentStackNo++ ;
} ;
while_ : while__ expression{
        char log_desc[MAX_BUFFER_LEN], previousTerm[MAX_BUFFER_LEN], currentTerm[MAX_BUFFER_LEN] ;
        stkpop(&Stack_top[currentStackNo], previousTerm, MAX_BUFFER_LEN) ;
        sprintf(log_desc, "t%d := %s\n", termNo++, previousTerm) ;
        logICG(log_desc) ;
        sprintf(log_desc, "t%d := not t%d\n", termNo, termNo-1) ;
        logICG(log_desc) ;
        sprintf(log_desc,"if (t%d) then goto end_loop_L%d\n", termNo++, labelNo ) ;
        logICG(log_desc) ;
        sprintf(log_desc,"loop_L%d:\n", labelNo) ;
        logICG(log_desc) ;
        labelNo++ ;
        sprintf(currentTerm,"if (%s) then goto loop_L%d", previousTerm, labelNo-1) ;
        stkpush(&Stack_top[currentStackNo], currentTerm) ;
} ;
while__ : WHILE {
        currentStackNo++ ;
} ;
Type : IDENTIFIER   { 
       strcpy(typesList[numTypes].actualType, $1) ;
     }
      | ARRAY LBRACKET SEQUENCE_DIGITS DOUBLEDOT SEQUENCE_DIGITS RBRACKET OF IDENTIFIER {
          strcpy(typesList[numTypes].actualType, $1) ;
          typesList[numTypes].typeArrayInfo.arrayLowerBound = $3 ; typesList[numTypes].typeArrayInfo.arrayUpperBound = $5 ;
          strcpy(typesList[numTypes].typeArrayInfo.arrayType, $8) ;
        }
      | RECORD record_section_list END {
                                          strcpy(typesList[numTypes].actualType, $1) ;
                                       } ;

record_section_list : record_section_list SEMICOLON record_section | record_section ;
record_section : RECORD_IDENTIFIER_LIST COLON IDENTIFIER { addRecordFieldsType($3) ; } ;
RECORD_IDENTIFIER_LIST : RECORD_IDENTIFIER_LIST COMMA IDENTIFIER {
			 int numSubRecords = typesList[numTypes].numSubVariables ; 
			 strcpy(typesList[numTypes].subRecordVariables[numSubRecords].variableName, $3) ;
                         typesList[numTypes].numSubVariables ++ ;
                      } 
                      | IDENTIFIER {
			 int numSubRecords = typesList[numTypes].numSubVariables ; 
			 strcpy(typesList[numTypes].subRecordVariables[numSubRecords].variableName, $1) ;
                         typesList[numTypes].numSubVariables ++ ;
                      } ;

expression : simple_expression {
		char previousTerm[MAX_BUFFER_LEN], currentTerm[MAX_BUFFER_LEN] ;
		stkpop(&Stack_top[currentStackNo], previousTerm, MAX_BUFFER_LEN) ;
                sprintf(currentTerm,"%s", previousTerm ) ;
		stkpush(&Stack_top[currentStackNo], currentTerm) ;
           }
           | simple_expression relational_operator simple_expression {
		char previousTerm1[MAX_BUFFER_LEN], previousTerm2[MAX_BUFFER_LEN], previousTerm3[MAX_BUFFER_LEN], currentTerm[MAX_BUFFER_LEN] ;
		stkpop(&Stack_top[currentStackNo], previousTerm3, MAX_BUFFER_LEN) ;
		stkpop(&Stack_top[currentStackNo], previousTerm2, MAX_BUFFER_LEN) ;
		stkpop(&Stack_top[currentStackNo], previousTerm1, MAX_BUFFER_LEN) ;
                sprintf(currentTerm,"%s %s %s ", previousTerm1, previousTerm2, previousTerm3) ;
		stkpush(&Stack_top[currentStackNo], currentTerm) ;
		//printf("expression relational_operator %s\n", currentTerm) ;
           };

assignment_expression : assignment_simple_expression {
		        char previousTerm[MAX_BUFFER_LEN], currentTerm[MAX_BUFFER_LEN] ;
		        stkpop(&Stack_top[currentStackNo], previousTerm, MAX_BUFFER_LEN) ;
                        sprintf(currentTerm,"%s", previousTerm ) ;
		        stkpush(&Stack_top[currentStackNo], currentTerm) ;
		        //printf("assignment_expression %s\n", currentTerm) ;
                      }
                      | assignment_simple_expression relational_operator assignment_simple_expression {
                        char previousTerm1[MAX_BUFFER_LEN], previousTerm2[MAX_BUFFER_LEN], previousTerm3[MAX_BUFFER_LEN], currentTerm[MAX_BUFFER_LEN] ;
                        stkpop(&Stack_top[currentStackNo], previousTerm3, MAX_BUFFER_LEN) ;
                        stkpop(&Stack_top[currentStackNo], previousTerm2, MAX_BUFFER_LEN) ;
                        stkpop(&Stack_top[currentStackNo], previousTerm1, MAX_BUFFER_LEN) ;
                        sprintf(currentTerm,"%s %s %s ", previousTerm1, previousTerm2, previousTerm3) ;
                        stkpush(&Stack_top[currentStackNo], currentTerm) ;
                        //printf("assignment_expression relational_operator %s\n", currentTerm) ;
                      } ;

simple_expression : term  {
		    char previousTerm[MAX_BUFFER_LEN], currentTerm[MAX_BUFFER_LEN] ;
		    stkpop(&Stack_top[currentStackNo], previousTerm, MAX_BUFFER_LEN) ;
                    sprintf(currentTerm, "%s", previousTerm) ;
		    stkpush(&Stack_top[currentStackNo], currentTerm) ;
		    //printf("simple_expression %s\n", currentTerm) ;
                  }| simple_expression add_operator term 
                  {
                    char previousTerm1[MAX_BUFFER_LEN], previousTerm2[MAX_BUFFER_LEN], previousTerm3[MAX_BUFFER_LEN], currentTerm[MAX_BUFFER_LEN] ;
                    stkpop(&Stack_top[currentStackNo], previousTerm3, MAX_BUFFER_LEN) ;
                    stkpop(&Stack_top[currentStackNo], previousTerm2, MAX_BUFFER_LEN) ;
                    stkpop(&Stack_top[currentStackNo], previousTerm1, MAX_BUFFER_LEN) ;
                    char log_desc[MAX_BUFFER_LEN] ;
                    sprintf(log_desc, "t%d := %s %s %s\n", termNo, previousTerm1, previousTerm2, previousTerm3) ;
                    logICG(log_desc) ;
                    sprintf(currentTerm, "t%d", termNo) ;
                    stkpush(&Stack_top[currentStackNo], currentTerm) ;
                    termNo++ ;
                    //printf("simple_expression add_operator %s\n", currentTerm) ;
                  };
assignment_simple_expression : assignment_term  {} | assignment_simple_expression add_operator assignment_term {
                    char previousTerm1[MAX_BUFFER_LEN], previousTerm2[MAX_BUFFER_LEN], previousTerm3[MAX_BUFFER_LEN], currentTerm[MAX_BUFFER_LEN] ;
                    stkpop(&Stack_top[currentStackNo], previousTerm3, MAX_BUFFER_LEN) ;
                    stkpop(&Stack_top[currentStackNo], previousTerm2, MAX_BUFFER_LEN) ;
                    stkpop(&Stack_top[currentStackNo], previousTerm1, MAX_BUFFER_LEN) ;
                    char log_desc[MAX_BUFFER_LEN] ;
                    sprintf(log_desc, "t%d := %s %s %s\n", termNo, previousTerm1, previousTerm2, previousTerm3) ;
                    logICG(log_desc) ;
                    sprintf(currentTerm, "t%d", termNo) ;
                    stkpush(&Stack_top[currentStackNo], currentTerm) ;
                    termNo++ ;
                    //printf("assignment_simple_expression add_operator %s\n", currentTerm) ;
                  } ;
term : factor  {
        char previousTerm[MAX_BUFFER_LEN], currentTerm[MAX_BUFFER_LEN] ; 
        stkpop(&Stack_top[currentStackNo], previousTerm, MAX_BUFFER_LEN) ;
        sprintf(currentTerm, "%s", previousTerm) ;
        stkpush(&Stack_top[currentStackNo], currentTerm) ;
        //printf("term %s\n", currentTerm) ;
       }| term mul_operator factor {
                    char previousTerm1[MAX_BUFFER_LEN], previousTerm2[MAX_BUFFER_LEN], previousTerm3[MAX_BUFFER_LEN], currentTerm[MAX_BUFFER_LEN] ;
                    stkpop(&Stack_top[currentStackNo], previousTerm3, MAX_BUFFER_LEN) ;
                    stkpop(&Stack_top[currentStackNo], previousTerm2, MAX_BUFFER_LEN) ;
                    stkpop(&Stack_top[currentStackNo], previousTerm1, MAX_BUFFER_LEN) ;
                    char log_desc[MAX_BUFFER_LEN] ;
                    sprintf(log_desc, "t%d := %s %s %s\n", termNo, previousTerm1, previousTerm2, previousTerm3) ;
                    logICG(log_desc) ;
                    sprintf(currentTerm, "t%d", termNo) ;
                    stkpush(&Stack_top[currentStackNo], currentTerm) ;
                    //printf("term mul_operator %s\n", currentTerm) ;
                    termNo++ ;
                 };
assignment_term : assignment_factor { 
        char previousTerm[MAX_BUFFER_LEN], currentTerm[MAX_BUFFER_LEN] ; 
        stkpop(&Stack_top[currentStackNo], previousTerm, MAX_BUFFER_LEN) ;
        sprintf(currentTerm, "%s", previousTerm) ;
        stkpush(&Stack_top[currentStackNo], currentTerm) ;
        //printf("assignment_term %s\n", currentTerm) ;
      }| assignment_term mul_operator assignment_factor {
                    char previousTerm1[MAX_BUFFER_LEN], previousTerm2[MAX_BUFFER_LEN], previousTerm3[MAX_BUFFER_LEN], currentTerm[MAX_BUFFER_LEN] ;
                    stkpop(&Stack_top[currentStackNo], previousTerm3, MAX_BUFFER_LEN) ;
                    stkpop(&Stack_top[currentStackNo], previousTerm2, MAX_BUFFER_LEN) ;
                    stkpop(&Stack_top[currentStackNo], previousTerm1, MAX_BUFFER_LEN) ;
                    char log_desc[MAX_BUFFER_LEN] ;
                    sprintf(log_desc, "t%d := %s %s %s\n", termNo, previousTerm1, previousTerm2, previousTerm3) ;
                    logICG(log_desc) ;
                    sprintf(currentTerm, "t%d", termNo) ;
                    stkpush(&Stack_top[currentStackNo], currentTerm) ;
                    //printf("assignment_term mul_operator current term %s\n", currentTerm) ;
                    termNo++ ;
                };

factor : SEQUENCE_DIGITS {
           char temp[MAX_BUFFER_LEN] ;
           sprintf(temp,"%d", $1) ;
           stkpush(&Stack_top[currentStackNo], temp) ;
       }| STRING {
           strcpy(assignmentExprTerms[numAssignmentTerms++].types, "string") ;
           stkpush(&Stack_top[currentStackNo], $1) ;
       }| variable_access {
        char previousTerm[MAX_BUFFER_LEN], currentTerm[MAX_BUFFER_LEN] ; 
        stkpop(&Stack_top[currentStackNo], previousTerm, MAX_BUFFER_LEN) ;
        sprintf(currentTerm, "%s", previousTerm) ;
        stkpush(&Stack_top[currentStackNo], currentTerm) ;
        //printf("factor variable_access %s\n", currentTerm) ;
       }| function_reference {
        char previousTerm[MAX_BUFFER_LEN], currentTerm[MAX_BUFFER_LEN] ; 
        stkpop(&Stack_top[currentStackNo], previousTerm, MAX_BUFFER_LEN) ;
        sprintf(currentTerm, "%s", previousTerm) ;
        stkpush(&Stack_top[currentStackNo], currentTerm) ;
        //printf("factor function_reference %s\n", currentTerm) ;
       }| NOT factor {
            char previousTerm[MAX_BUFFER_LEN], currentTerm[MAX_BUFFER_LEN] ;
            stkpop(&Stack_top[currentStackNo], previousTerm, MAX_BUFFER_LEN) ;
            char log_desc[MAX_BUFFER_LEN] ;
            sprintf(log_desc, "t%d := not %s\n", termNo, previousTerm) ;
            logICG(log_desc) ;
            sprintf(currentTerm, "t%d",termNo) ;
            stkpush(&Stack_top[currentStackNo], currentTerm) ;
            termNo++ ;
       }| MINUS factor {
            char previousTerm[MAX_BUFFER_LEN], currentTerm[MAX_BUFFER_LEN] ;
            stkpop(&Stack_top[currentStackNo], previousTerm, MAX_BUFFER_LEN) ;
            char log_desc[MAX_BUFFER_LEN] ;
            sprintf(log_desc, "t%d := - %s\n", termNo, previousTerm) ;
            logICG(log_desc) ;
            sprintf(currentTerm, "t%d",termNo) ;
            stkpush(&Stack_top[currentStackNo], currentTerm) ;
            termNo++ ;
       }
       | LPARENTHESIS expression RPARENTHESIS {
            char previousTerm[MAX_BUFFER_LEN], currentTerm[MAX_BUFFER_LEN] ;
            stkpop(&Stack_top[currentStackNo], previousTerm, MAX_BUFFER_LEN) ;
            sprintf(currentTerm, "(%s)", previousTerm) ;
            stkpush(&Stack_top[currentStackNo], currentTerm) ;
       }
       | TRUE_BOOLEAN {
           strcpy(assignmentExprTerms[numAssignmentTerms++].types, "boolean") ;
           stkpush(&Stack_top[currentStackNo], $1) ;
       }
       | FALSE_BOOLEAN {
           strcpy(assignmentExprTerms[numAssignmentTerms++].types, "boolean") ;
           stkpush(&Stack_top[currentStackNo], $1) ;
       };

assignment_factor : SEQUENCE_DIGITS  {
           strcpy(assignmentExprTerms[numAssignmentTerms++].types, "integer") ;
           char currentTerm[MAX_BUFFER_LEN] ;
           sprintf(currentTerm,"%d", $1) ;
           stkpush(&Stack_top[currentStackNo], currentTerm) ;
         }| STRING {
           strcpy(assignmentExprTerms[numAssignmentTerms++].types, "string") ;
           stkpush(&Stack_top[currentStackNo], $1) ;
         }| TRUE_BOOLEAN {
           strcpy(assignmentExprTerms[numAssignmentTerms++].types, "boolean") ;
           stkpush(&Stack_top[currentStackNo], $1) ;
         }| FALSE_BOOLEAN {
           strcpy(assignmentExprTerms[numAssignmentTerms++].types, "boolean") ;
           stkpush(&Stack_top[currentStackNo], $1) ;
         }| assignment_variable_access {
          char previousTerm[MAX_BUFFER_LEN], currentTerm[MAX_BUFFER_LEN] ; 
          stkpop(&Stack_top[currentStackNo], previousTerm, MAX_BUFFER_LEN) ;
          sprintf(currentTerm, "%s", previousTerm) ;
          stkpush(&Stack_top[currentStackNo], currentTerm) ;
         }| assignment_function_reference {
           char previousTerm[MAX_BUFFER_LEN], currentTerm[MAX_BUFFER_LEN] ; 
           stkpop(&Stack_top[currentStackNo], previousTerm, MAX_BUFFER_LEN) ;
           sprintf(currentTerm, "%s", previousTerm) ;
           stkpush(&Stack_top[currentStackNo], currentTerm) ;
           //printf("assignment_factor assignment_function_reference %s\n", currentTerm) ;
         }| NOT factor{
            char previousTerm[MAX_BUFFER_LEN], currentTerm[MAX_BUFFER_LEN] ;
            stkpop(&Stack_top[currentStackNo], previousTerm, MAX_BUFFER_LEN) ;
            char log_desc[MAX_BUFFER_LEN] ;
            sprintf(log_desc, "t%d := not %s\n", termNo, previousTerm) ;
            logICG(log_desc) ;
            sprintf(currentTerm, "t%d",termNo) ;
            stkpush(&Stack_top[currentStackNo], currentTerm) ;
            termNo++ ;
         }| MINUS assignment_factor  {
            char previousTerm[MAX_BUFFER_LEN], currentTerm[MAX_BUFFER_LEN] ;
            stkpop(&Stack_top[currentStackNo], previousTerm, MAX_BUFFER_LEN) ;
            char log_desc[MAX_BUFFER_LEN] ;
            sprintf(log_desc, "t%d := - %s\n", termNo, previousTerm) ;
            logICG(log_desc) ;
            sprintf(currentTerm, "t%d",termNo) ;
            stkpush(&Stack_top[currentStackNo], currentTerm) ;
            termNo++ ;
          }
          | LPARENTHESIS assignment_expression RPARENTHESIS {
            char previousTerm[MAX_BUFFER_LEN], currentTerm[MAX_BUFFER_LEN] ;
            stkpop(&Stack_top[currentStackNo], previousTerm, MAX_BUFFER_LEN) ;
            char log_desc[MAX_BUFFER_LEN] ;
            sprintf(log_desc, "t%d := (%s)\n", termNo, previousTerm) ;
            logICG(log_desc) ;
            sprintf(currentTerm, "t%d",termNo) ;
            stkpush(&Stack_top[currentStackNo], currentTerm) ;
            termNo++ ;
          };


function_reference : IDENTIFIER params {
            int i ;
            for(i = 0; i < currentSubProgram; i++) {
                if(strcmp(subProgram[i].name, $1) == 0) {
                   break ;
                }
            }
            if(i == currentSubProgram) {
                printf("<error> undefined reference to function/procedure %s\n", $1) ;
            }
            char currentTerm[MAX_BUFFER_LEN] ;
            char log_desc[MAX_BUFFER_LEN] ;
            sprintf(log_desc, "t%d := funcall %s\n", termNo, $1) ;
            logICG(log_desc) ;
            sprintf(currentTerm, "t%d", termNo) ;
            stkpush(&Stack_top[currentStackNo], currentTerm) ;
            termNo++ ;
            //printf("function reference current term %s\n", currentTerm) ;
         };
assignment_function_reference : IDENTIFIER params {
            int i ;
            for(i = 0; i < currentSubProgram; i++) {
                if(strcmp(subProgram[i].name, $1) == 0) {
	           strcpy(assignmentExprTerms[numAssignmentTerms++].types, subProgram[i].returnType) ;
                   break ;
                }
            }
            if(i == currentSubProgram) {
                printf("<error> undefined reference to function/procedure %s\n", $1) ;
                flagAssignmentInvalid = 1 ;
            }
            char currentTerm[MAX_BUFFER_LEN] ;
            char log_desc[MAX_BUFFER_LEN] ;
            sprintf(log_desc, "t%d :=  funcall %s\n", termNo, $1) ;
            logICG(log_desc) ;
            sprintf(currentTerm, "t%d", termNo) ;
            stkpush(&Stack_top[currentStackNo], currentTerm) ;
            termNo++ ;
            //printf("assignment function reference current term %s\n", currentTerm) ;
         };

add_operator : PLUS {
                char currentTerm[MAX_BUFFER_LEN] ;
                stkpush(&Stack_top[currentStackNo], " + ") ;
             }
             | MINUS {
                char currentTerm[MAX_BUFFER_LEN] ;
                stkpush(&Stack_top[currentStackNo], " - ") ;
             }| OR {
                char currentTerm[MAX_BUFFER_LEN] ;
                stkpush(&Stack_top[currentStackNo], " or ") ;
             };
mul_operator : STAR { 
              char currentTerm[MAX_BUFFER_LEN] ;
              stkpush(&Stack_top[currentStackNo], " * ") ;
	     }
	     | DIV {
              char currentTerm[MAX_BUFFER_LEN] ;
              stkpush(&Stack_top[currentStackNo], " / ") ;
             }
             | MOD {
                char currentTerm[MAX_BUFFER_LEN] ;
                stkpush(&Stack_top[currentStackNo], " mod ") ;
             }
             | AND  {
              char currentTerm[MAX_BUFFER_LEN] ;
              stkpush(&Stack_top[currentStackNo], " and ") ;
	     };
relational_operator : EQUAL {
                      char currentTerm[MAX_BUFFER_LEN] ;
                      stkpush(&Stack_top[currentStackNo], " = ") ;
                    }| NOTEQUAL {
                      char currentTerm[MAX_BUFFER_LEN] ;
                      stkpush(&Stack_top[currentStackNo], " <> ") ;
                    }| LT {
                      char currentTerm[MAX_BUFFER_LEN] ;
                      stkpush(&Stack_top[currentStackNo], " < ") ;
                    }| GT {
                      char currentTerm[MAX_BUFFER_LEN] ;
                      stkpush(&Stack_top[currentStackNo], " > ") ;
                    }| LE {
                      char currentTerm[MAX_BUFFER_LEN] ;
                      stkpush(&Stack_top[currentStackNo], " <= ") ;
                    }| GE {
                      char currentTerm[MAX_BUFFER_LEN] ;
                      stkpush(&Stack_top[currentStackNo], " >= ") ;
                    };

variable_access : IDENTIFIER {
                  int ret = isVariableDefined($1) ;
                  if(ret == 0) {
                     if(flagGlobalScope == 1) {
                       printf("<error> undefined variable %s referenced in global scope\n", $1) ;
                     }
                     if(flagGlobalScope == 0) {
                       if(subProgram[currentSubProgram].scopeType == FUNCTIONAL_SCOPE) {
                         printf("<error> undefined variable %s referenced in function %s\n", $1, subProgram[currentSubProgram].name) ;
                       }
                       else if(subProgram[currentSubProgram].scopeType == PROCEDURAL_SCOPE) {
                         printf("<error> undefined variable %s referenced in procedure %s\n", $1, subProgram[currentSubProgram].name) ;
                       }
                     }
                  }
                  char currentTerm[MAX_BUFFER_LEN] ;
                  sprintf(currentTerm,"%s", $1) ;
                  //printf("variable access %s\n", currentTerm) ;
                  stkpush(&Stack_top[currentStackNo], currentTerm) ;
                }
                | indexed_variable | field_designator ;

assignment_variable_access : IDENTIFIER {
                  int ret = assignmentLHSDefined($1) ;
                  if(ret == 0) {
                     if(flagGlobalScope == 1) {
                       printf("<error> undefined variable %s referenced in global scope\n", $1) ;
                       flagAssignmentInvalid = 1 ;
                     }
                     if(flagGlobalScope == 0) {
                       if(subProgram[currentSubProgram].scopeType == FUNCTIONAL_SCOPE) {
                         printf("<error> undefined variable %s referenced in function %s\n", $1, subProgram[currentSubProgram].name) ;
                         flagAssignmentInvalid = 1 ;
                       }
                       else if(subProgram[currentSubProgram].scopeType == PROCEDURAL_SCOPE) {
                         printf("<error> undefined variable %s referenced in procedure %s\n", $1, subProgram[currentSubProgram].name) ;
                         flagAssignmentInvalid = 1 ;
                       }
                     }
                  }
                  char currentTerm[MAX_BUFFER_LEN] ;
                  sprintf(currentTerm,"%s", $1) ;
                  //printf("assignment variable access %s\n", currentTerm) ;
                  stkpush(&Stack_top[currentStackNo], currentTerm) ;
                }
                | indexed_variable | field_designator ;

indexed_variable : variable_access LBRACKET index_expression_list RBRACKET {
            char previousTerm1[MAX_BUFFER_LEN], previousTerm2[MAX_BUFFER_LEN], currentTerm[MAX_BUFFER_LEN] ;
            stkpop(&Stack_top[currentStackNo], previousTerm2, MAX_BUFFER_LEN) ;
            stkpop(&Stack_top[currentStackNo], previousTerm1, MAX_BUFFER_LEN) ;
            sprintf(currentTerm, "%s[%s]", previousTerm1, previousTerm2) ;
            //printf("index variable current term %s %d\n", currentTerm, currentStackNo) ;
            stkpush(&Stack_top[currentStackNo], currentTerm) ;
} ;

index_expression_list : index_expression_list COMMA expression {
            char previousTerm1[MAX_BUFFER_LEN], previousTerm2[MAX_BUFFER_LEN], currentTerm[MAX_BUFFER_LEN] ;
            stkpop(&Stack_top[currentStackNo], previousTerm2, MAX_BUFFER_LEN) ;
            stkpop(&Stack_top[currentStackNo], previousTerm1, MAX_BUFFER_LEN) ;
            sprintf(currentTerm, "%s,%s", previousTerm1, previousTerm2) ;
            //printf("index expression list current term %s\n", currentTerm) ;
            stkpush(&Stack_top[currentStackNo], currentTerm) ;
          }| expression{
          };

field_designator : IDENTIFIER DOT IDENTIFIER {
                  int ret = isVariableDefined($1) ;
                  if(ret == 0) {
                     if(flagGlobalScope == 1) {
                       printf("<error> undefined variable %s referenced in global scope\n", $1) ;
                     }
                     if(flagGlobalScope == 0) {
                       if(subProgram[currentSubProgram].scopeType == FUNCTIONAL_SCOPE) {
                         printf("<error> undefined variable %s referenced in function %s\n", $1, subProgram[currentSubProgram].name) ;
                       }
                       else if(subProgram[currentSubProgram].scopeType == PROCEDURAL_SCOPE) {
                         printf("<error> undefined variable %s referenced in procedure %s\n", $1, subProgram[currentSubProgram].name) ;
                       }
                     }
                  }
                  else {
		    ret = checkSubRecordExists($1, $3) ;
                    if(ret == 0) {
                       if(flagGlobalScope == 1) {
                         printf("<error> undefined variable %s referenced in global scope as field of %s\n", $3, $1) ;
                       }
                       if(flagGlobalScope == 0) {
                         if(subProgram[currentSubProgram].scopeType == FUNCTIONAL_SCOPE) {
                           printf("<error> undefined variable %s referenced in function %s as field of %s\n", $3, subProgram[currentSubProgram].name, $1) ;
                         }
                         else if(subProgram[currentSubProgram].scopeType == PROCEDURAL_SCOPE) {
                           printf("<error> undefined variable %s referenced in procedure %s as field of %s\n", $3, subProgram[currentSubProgram].name, $1) ;
                         }
                       }
                    }
                  }
                  char currentTerm[MAX_BUFFER_LEN] ;
                  sprintf(currentTerm, "%s.%s", $1, $3) ;
                  stkpush(&Stack_top[currentStackNo], currentTerm) ;
		} ;

%%

int main() {
  FILE *fp = fopen("a.txt", "w") ;
  if(fp != NULL) {
    fclose(fp) ;
  }
  int i ;
  for(i = 0 ; i < 1000; i++) {
    Stack_top[i] = NULL ;
  }
  memset(typesList, 0, sizeof(struct typeList)*1000) ;
  memset(subProgram, 0, sizeof(struct subprogramList)*1000) ;
  numAssignmentTerms = 0 ;
  memset(assignmentExprTerms, 0, sizeof(struct assignmentExpressionTerms) * 100) ;

  subProgram[GLOBAL_SUBPROGRAM].scopeType = GLOBAL_SCOPE ;
  yyparse() ;

  /*printf("\n\nList of Types:\n") ;
  int i = 0 ;
  for(i =0; i < numTypes; i++) {
     if(strcmp(typesList[i].actualType, "record") == 0) {
        int j = 0;
        for(j=0; j < typesList[i].numSubVariables; j++) {
          printf("Type: %s %s %s %s\n", typesList[i].aliasType, typesList[i].actualType, typesList[i].subRecordVariables[j].variableName, typesList[i].subRecordVariables[j].variableType) ;
        }
     }
     else if(strcmp(typesList[i].actualType, "array") == 0) {
        printf("Type: %s %s %s bounds %d %d\n", typesList[i].aliasType, typesList[i].actualType, typesList[i].typeArrayInfo.arrayType, typesList[i].typeArrayInfo.arrayLowerBound, typesList[i].typeArrayInfo.arrayUpperBound) ;
     }
     else {
        printf("Type: %s %s\n", typesList[i].aliasType, typesList[i].actualType ) ;
     }
  }
  printf("\n\nList of subprograms and their variables:\n") ;
  for(i = 0; i < currentSubProgram; i++) {
     int  j ;
     if(i == GLOBAL_SUBPROGRAM) {
        for(j = 0; j < subProgram[i].numVar; j++) {
          printf("(Scope Global:) variable %s %s\n", subProgram[i].subProgramVariableList[j].variableName, subProgram[i].subProgramVariableList[j].variableType) ;
        }
     }
     else {
        for(j = 0; j < subProgram[i].numVar; j++) {
          if(subProgram[i].scopeType == FUNCTIONAL_SCOPE) {
             printf("(Scope function %s return type %s:) variable %s %s\n", subProgram[i].name, subProgram[i].returnType, subProgram[i].subProgramVariableList[j].variableName, subProgram[i].subProgramVariableList[j].variableType) ;
          }
          if(subProgram[i].scopeType == PROCEDURAL_SCOPE) {
             printf("(Scope procedure %s return type %s:) variable %s %s\n", subProgram[i].name, subProgram[i].returnType, subProgram[i].subProgramVariableList[j].variableName, subProgram[i].subProgramVariableList[j].variableType) ;
          }
        }
     }
  }*/
  return  0 ;
}

void addType(char *aliasType) {
   strcpy(typesList[numTypes].aliasType, aliasType) ;
   if(strcmp(typesList[numTypes].actualType, "record") == 0) {
      checkDuplicateSubRecords() ;
   }
   numTypes++ ;
}

void checkDuplicateTypes() {
   int i, j ;
   //check if the type is duplicate
   for(i = 0 ; i < numTypes; i++) {
     if(typesList[i].flagDuplicateType == 0) {
       for(j =0 ; j <numTypes; j++) {
         if(i != j) {
           if(strcmp(typesList[i].aliasType, typesList[j].aliasType) == 0) {
               printf("<error>: Two types with same name: %s - %s %s - %s\n", typesList[i].aliasType, typesList[i].actualType, typesList[j].aliasType, typesList[j].actualType) ;
               typesList[i].flagDuplicateType = 1 ;
               typesList[j].flagDuplicateType = 1 ;
           }
         }
       }
     }
   }
}

void addRecordFieldsType(char *type) {
   int numSubVar = 0 ;
   for(numSubVar = 0; numSubVar < typesList[numTypes].numSubVariables; numSubVar++ ) {
     if(typesList[numTypes].subRecordVariables[numSubVar].variableType[0] == 0 ) {		//If variable in record has not been assigned a type yet
       strcpy(typesList[numTypes].subRecordVariables[numSubVar].variableType, type) ; 
     }
   }
}

void checkDuplicateSubRecords() {
  int i, j ;
  for(i = 0; i < typesList[numTypes].numSubVariables; i++) {
    if(typesList[numTypes].subRecordVariables[i].flagDuplicateVariable  == 0) {
      for(j = 0; j < typesList[numTypes].numSubVariables; j++) {
        if(j != i) {
          if(strcmp(typesList[numTypes].subRecordVariables[i].variableName, typesList[numTypes].subRecordVariables[j].variableName) == 0) {
             typesList[numTypes].subRecordVariables[i].flagDuplicateVariable = 1 ;
             typesList[numTypes].subRecordVariables[j].flagDuplicateVariable = 1 ;
             printf("<error>: Two fields in record %s with same name: %s - %s %s - %s\n", typesList[numTypes].aliasType,typesList[numTypes].subRecordVariables[i].variableName, typesList[numTypes].subRecordVariables[i].variableType, typesList[numTypes].subRecordVariables[j].variableName, typesList[numTypes].subRecordVariables[j].variableType ) ;
          }
        }
      }
    }
  }
}
void yyerror(const char *s) {
  printf("Parsing error: %s\n", s) ;
}

void assignVariableType(char *type, int subProgramNo) {
   int numVar = 0 ;
   for(numVar = 0; numVar < subProgram[subProgramNo].numVar; numVar++) {
     if(subProgram[subProgramNo].subProgramVariableList[numVar].variableType[0] == 0) {
       //Assigning type to those variables which have not been assigned
       strcpy(subProgram[subProgramNo].subProgramVariableList[numVar].variableType, type) ;
     }
   }
}

void checkDuplicateVariables() {
  int i, subProgramNo ;
  if(flagGlobalScope == 0) {
    subProgramNo = currentSubProgram ;
  }
  else {
    subProgramNo = GLOBAL_SUBPROGRAM ;
  }
  for(i = 0; i < subProgram[subProgramNo].numVar; i++) {
    if(subProgram[subProgramNo].subProgramVariableList[i].flagDuplicateVariable == 0) {
      int j ;
      for(j = 0; j < subProgram[subProgramNo].numVar; j++) {
         if(i != j) {
           if(strcmp(subProgram[subProgramNo].subProgramVariableList[i].variableName, subProgram[subProgramNo].subProgramVariableList[j].variableName) == 0) {
             subProgram[subProgramNo].subProgramVariableList[i].flagDuplicateVariable = 1 ;
             subProgram[subProgramNo].subProgramVariableList[j].flagDuplicateVariable = 1 ;
             if(subProgram[subProgramNo].scopeType == GLOBAL_SCOPE) {
                printf("Global error: ") ;
             }
             else if(subProgram[subProgramNo].scopeType == FUNCTIONAL_SCOPE){
                printf("In function %s: ", subProgram[subProgramNo].name) ;
             }
             else if(subProgram[subProgramNo].scopeType == PROCEDURAL_SCOPE){
                printf("In procedure %s: ", subProgram[subProgramNo].name) ;
             }
             printf("<error> Multiple declaration of variable %s - %s %s - %s\n", subProgram[subProgramNo].subProgramVariableList[i].variableName, subProgram[subProgramNo].subProgramVariableList[i].variableType, subProgram[subProgramNo].subProgramVariableList[j].variableName, subProgram[subProgramNo].subProgramVariableList[j].variableType) ;
           }

         }
      }
    }
  }
}

int assignmentLHSDefined(char *variableName) {
  int i = 0 ;
  if(flagGlobalScope == 0) {	//We are inside a function, check if the variable is in scope of the current function
    for(i = 0; i < subProgram[currentSubProgram].numVar; i++) {
      if(strcmp(subProgram[currentSubProgram].subProgramVariableList[i].variableName, variableName) == 0) {
         strcpy(assignmentExprTerms[numAssignmentTerms].name, subProgram[currentSubProgram].subProgramVariableList[i].variableName) ;
         strcpy(assignmentExprTerms[numAssignmentTerms++].types, subProgram[currentSubProgram].subProgramVariableList[i].variableType) ;
         //printf("Variable %s %s %d\n", assignmentExprTerms[numAssignmentTerms-1].name, assignmentExprTerms[numAssignmentTerms-1].types, numAssignmentTerms-1) ;
         return  1 ;
      }
    }
    if((i == subProgram[currentSubProgram].numVar ) && (subProgram[currentSubProgram].scopeType == FUNCTIONAL_SCOPE )&& (strcmp(subProgram[currentSubProgram].name, variableName) == 0)) {   //LHS of assignment is referring to function instead of variable
      strcpy(assignmentExprTerms[numAssignmentTerms].name, subProgram[currentSubProgram].name) ;
      strcpy(assignmentExprTerms[numAssignmentTerms].types, subProgram[currentSubProgram].returnType) ;
      assignmentExprTerms[numAssignmentTerms++].flagFunction = 1 ;
      return  1 ;
    }
  }
  for(i = 0; i < subProgram[GLOBAL_SUBPROGRAM].numVar; i++) {
    if(strcmp(subProgram[GLOBAL_SUBPROGRAM].subProgramVariableList[i].variableName, variableName) == 0) {
       strcpy(assignmentExprTerms[numAssignmentTerms].name, subProgram[GLOBAL_SUBPROGRAM].subProgramVariableList[i].variableName) ;
       strcpy(assignmentExprTerms[numAssignmentTerms++].types, subProgram[GLOBAL_SUBPROGRAM].subProgramVariableList[i].variableType) ;
       //printf("Variable %s %s %d\n", assignmentExprTerms[numAssignmentTerms-1].name, assignmentExprTerms[numAssignmentTerms-1].types, numAssignmentTerms-1) ;
       return  1 ;
    }
  }
  return 0 ;
}

int isVariableDefined(char *variableName) {
  int i = 0 ;
  if(flagGlobalScope == 0) {	//We are inside a function, check if the variable is in scope of the current function
    for(i = 0; i < subProgram[currentSubProgram].numVar; i++) {
      if(strcmp(subProgram[currentSubProgram].subProgramVariableList[i].variableName, variableName) == 0) {
         return  1 ;
      }
    }
  }
  for(i = 0; i < subProgram[GLOBAL_SUBPROGRAM].numVar; i++) {
    if(strcmp(subProgram[GLOBAL_SUBPROGRAM].subProgramVariableList[i].variableName, variableName) == 0) {
       return  1 ;
    }
  }
  return 0 ;
}

int checkSubRecordExists(char *recordName, char *subRecordName) {
  int i = 0, flagRecordFound = 0 ;
  char recordType[MAX_BUFFER_LEN] ;
  if(flagGlobalScope == 0) {	//We are inside a function, check if the variable is in scope of the current function
    for(i = 0; i < subProgram[currentSubProgram].numVar; i++) {
      if(strcmp(subProgram[currentSubProgram].subProgramVariableList[i].variableName, recordName) == 0 ) {         
         strcpy(recordType, subProgram[currentSubProgram].subProgramVariableList[i].variableType) ;
         flagRecordFound  = 1 ;
         break ;
      }
    }
    for(i = 0 ; i < numTypes; i++) {
      if(strcmp(typesList[i].aliasType, recordType) == 0 && strcmp(typesList[i].actualType, "record") == 0 ) {
         int j ;
         for(j = 0 ; j < typesList[i].numSubVariables; j++) {
           if(strcmp(typesList[i].subRecordVariables[j].variableName, subRecordName) == 0) {
             return 1 ;
           }
         }
      }
    }
  }
  if(flagRecordFound == 0) {	//if record isnt defined locally, check globally
    for(i = 0; i < subProgram[GLOBAL_SUBPROGRAM].numVar; i++) {
      if(strcmp(subProgram[GLOBAL_SUBPROGRAM].subProgramVariableList[i].variableName, recordName) == 0) {
         strcpy(recordType, subProgram[GLOBAL_SUBPROGRAM].subProgramVariableList[i].variableType) ;
         break ;
      }
    }
    for(i = 0 ; i < numTypes; i++) {
      if(strcmp(typesList[i].aliasType, recordType) == 0 && strcmp(typesList[i].actualType, "record") == 0 ) {
         int j ;
         for(j = 0 ; j < typesList[i].numSubVariables; j++) {
           if(strcmp(typesList[i].subRecordVariables[j].variableName, subRecordName) == 0) {
             return 1 ;
           }
         }
      }
    }
  }

  return  0 ;
}

void getActualType(char *aliasType, char *actualType, int *typeNo) {
  if(strcmp(aliasType, "integer") == 0 || strcmp(aliasType, "string") == 0 || strcmp(aliasType, "boolean") == 0) {
    strcpy(actualType, aliasType) ;
  }
  else {
    int i = 0;
    for(i = 0; i < numTypes; i++) {
      if(strcmp(typesList[i].aliasType, aliasType) == 0) {
         strcpy(actualType, typesList[i].actualType) ;
         *typeNo = i ;
         break ;
      }
    }
  }
}

void logICG(char *log_desc) {
   FILE *fp = fopen("a.txt", "a") ;
   if(fp == NULL) {
     printf("fopen error: Could not open a.txt %s\n", (char *)strerror(errno)) ;
   }
   else {
     fprintf(fp, "%s", log_desc) ;
     fclose(fp) ;
   }
   //printf("%s\n", log_desc) ;
}
