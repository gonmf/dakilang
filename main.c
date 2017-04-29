#define _POSIX_C_SOURCE 199309L
#define _XOPEN_SOURCE 600

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef enum __expr_type_ {
  constant,
  expr,
  variable
} expr_type;

typedef struct __argument_ {
  expr_type type;
  void * value;
} argument;

typedef struct __functor_ {
  char name[32];
  int arity;
  argument args[10];
} functor;

typedef struct __fact_ {
  functor func;
  argument condition;
} fact;

static void main_loop(){
  return;



  while(1){
    printf("?- ");

  }
}

static char * trim(char * s) {
  while(*s == ' ' || *s == '\t')
    ++s;

  char * ret = s;
  int len = strlen(s);
  for (int i = len - 1; i >= 0; --i)
    if (s[i] == ' ' || s[i] == '\t')
      s[i] = 0;
    else
      break;

  return ret;
}

static void cut_string_at(char * s, char sep) {
  while(*s) {
    if (*s == sep) {
      *s = 0;
      return;
    }
    ++s;
  }
}

static int index_of(char * s, char c) {
  int i = 0;
  while(*s) {
    if (*s == c)
      return i;
    ++s;
    ++i;
  }

  return -1;
}

static int parse_functor(char * s, functor * f);

// TODO: for now only accept string arguments
static int parse_argument(char * s, argument * a) {
  s = trim(s);

  int low_limit = index_of(s, '(');
  if (low_limit < 1) {
    a->type = constant;
    int len = strlen(s);
    a->value = malloc(len + 1);
    memcpy(a->value, s, len);
    ((char * )a->value)[len] = 0;
    return 1;
  } else {
    a->type = expr;
    a->value = malloc(sizeof(functor));
    parse_functor(s, (functor *)a->value);
    return 1;
  }
}

static int parse_functor(char * s, functor * f) {
  int len = strlen(s);
  int low_limit = index_of(s, '(');
  if (low_limit < 1 || s[len - 1] != ')')
    return 0;


  memcpy(f->name, s, low_limit);
  f->name[low_limit] = 0;
  f->arity = 0;

  s[len - 1] = 0;
  s = s + low_limit + 1;

  char * saveptr = NULL;
  while(1) {
    char * arg_str = strtok_r(s, ",", &saveptr);
    s = NULL;
    if (arg_str == NULL)
      break;
    if (parse_argument(arg_str, &f->args[f->arity])){
      f->arity++;
    }
  }

  return 1;
}

static void print_functor(functor * f);
static void print_arg(argument * a) {
  switch(a->type){
    case constant:
      printf("c:%s", (char *)a->value);
      break;
    case expr:
      print_functor((functor *)a->value);
      break;
  }
}

static void print_functor(functor * f) {
  printf("f:%s", f->name);
  if (f->arity > 0) {
    printf("(");
    for (int i = 0; i < f->arity; ++i){
      if (i != 0)
        printf(",");

      print_arg(&f->args[i]);
    }
    printf(")");
  }
}


static void print_fact(fact * f) {
  print_functor(&f->func);
  printf(" :- ");
  print_arg(&f->condition);

  printf("\n\n");
}

// Returns 1 on success, 0 on ignored, -1 on error
static int parse_fact(char * fact_line) {
  fact_line = trim(fact_line);
  cut_string_at(fact_line, '%');
  int len = strlen(fact_line);
  if (len == 0)
    return 0;

  printf("%s\n", fact_line);

  if (fact_line[len - 1] == '.')
    fact_line[len - 1] = 0;

  char * sep = strstr(fact_line, " :- ");
  char * fact_line1;
  char * fact_line2;
  if (sep != NULL) {
    fact_line1 = fact_line;
    fact_line1[sep - fact_line] = 0;
    fact_line2 = sep + strlen(" :- ");
  } else {
    fact_line1 = fact_line;
    fact_line2 = "1";
  }

  fact new_fact;
  int is_functor = parse_functor(fact_line1, &new_fact.func);
  if (is_functor) {
    parse_argument(fact_line2, &new_fact.condition);
    print_fact(&new_fact);
  }

  return 1;
}

static int consult(const char * file_name){
  char * buffer = malloc(1024 * 1024);

  FILE * fp = fopen(file_name, "r");
  if (fp == NULL) {
    free(buffer);
    return 0;
  }

  int r = (int)fread(buffer, 1, 1024 * 1024, fp);
  int err = ferror(fp);
  fclose(fp);
  printf("Read %d bytes.\n\n", r);

  if (err || r <= 0) {
      free(buffer);
      return 0;
  }

  buffer[r] = 0;

  char * buffer_ptr = buffer;
  int facts = 0;
  char * saveptr = NULL;
  while(1) {
    char * line = strtok_r(buffer_ptr, "\n\r", &saveptr);
    buffer_ptr = NULL;
    if (line == NULL)
      break;

    int parse_result = parse_fact(line);
    if(parse_result < 0){
      printf("Parse error.\n");
      free(buffer);
      return 0;
    }

    if (parse_result > 0)
      ++facts;
  }

  printf("\nLoaded %d facts.\n", facts);

  return 1;
}

static void print_usage(const char * program_name){
  printf("%s [knowledge_base]\n\n", program_name);
}

int main(int argc, char * argv[]){
  if(argc > 2){
    print_usage(argv[0]);
    return EXIT_FAILURE;
  }

  if(argc == 2){
    if(!consult(argv[1])){
      return EXIT_FAILURE;
    }
  }

  main_loop();
  return EXIT_SUCCESS;
}
