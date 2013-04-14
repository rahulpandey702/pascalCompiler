typedef struct list
{
        char data[1024];
        struct list *next;
} LIST ;

void stkpush(struct list **, char *);
void stkpop(struct list **, char *retv, int len);
int check_stack_empty(struct list **);
