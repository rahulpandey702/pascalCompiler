#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <errno.h>
#include "stack.h"

extern LIST *Stack_top[];

void stkpush(LIST **top, char *data)
{
	LIST *temp;

	temp = (LIST *) malloc(sizeof(LIST));
	memset(temp, 0, sizeof(LIST)) ;

	strcpy(temp->data, data);
        temp->next = *top;
        *top = temp;

/*	printf("Element pushed:%c\n",(*top)->data);*/
}

int check_stack_empty(LIST **top)
{
	if((*top) == NULL)
		return 1;

	else return 0;
}



void stkpop(LIST **top, char *retv, int len)
{
	LIST *temp;
        if(check_stack_empty(top) == 0) {
	  temp = *top;
	  strcpy(retv, (*top)->data) ;
	  *top = (*top)->next;
	  free(temp);
         // printf("Popping %s\n", retv) ;
	}
	else {
          memset(retv, 0, len) ;
	  //printf("stkpop: stack is empty\n") ;
	}
/*	printf("Top is:%c\n",retv);*/
	
}



