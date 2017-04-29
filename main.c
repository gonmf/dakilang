#define _POSIX_C_SOURCE 199309L
#define _XOPEN_SOURCE 600

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_FACTS 100

typedef enum __expr_type_ {
  constant_atom,
  constant_number,
  expr, // functor
  variable,
  any,
} expr_type;

typedef struct __term_ {
  expr_type type;
  char * variable_name;
  void * value;
} term;

typedef struct __functor_ {
  char name[32];
  int arity;
  term args[10];
} functor;

typedef struct __fact_ {
  functor func;
  term condition;
} fact;

static fact * knowledge_base[MAX_FACTS];

static int eval_term(term * t) {
  return 1;
}

static int eval_functor(functor * f) {
  int i = 0;
  while(knowledge_base[i] != NULL) {
    fact * my_fact = knowledge_base[i++];

    functor * saved = &my_fact->func;
    if (strcmp(saved->name, f->name) == 0 && f->arity == saved->arity) {
      if (eval_term(&my_fact->condition)){
        for(int j = 0; j < saved->arity; ++j) {
          if (saved->args[j].type == variable && f->args[j].type == variable)
            continue;
          if (saved->args[j].type != variable && f->args[j].type == variable){
            f->args[j].value = saved->args[j].value;
            f->args[j].type = saved->args[j].type;
            if (eval_functor(f))
              return 1;
            f->args[j].value = NULL;
            f->args[j].type = variable;
            return 0;
          }
          if (saved->args[j].type != f->args[j].type)
            return 0;
          if (strcmp((char *)saved->args[j].value, (char *)f->args[j].value) != 0)
            return 0;
        }

        return 1;
      }
    }
  }

  return 0;
}

static int eval_fact(fact * f) {
  if (eval_term(&f->condition) && eval_functor(&f->func)) {
    for (int i = 0; i < f->func.arity; ++i) {
      if (f->func.args[i].variable_name != NULL) {
        if (f->func.args[i].value == NULL)
          printf("%s = (any)\n", f->func.args[i].variable_name);
        else
          printf("%s = %s\n", f->func.args[i].variable_name, (char *)f->func.args[i].value);
      }
    }
    return 1;
  }
  return 0;
}

static void print_fact(fact * f);
static char * trim(char * s);
static int parse_fact(char * fact_line, fact * new_fact);
static void main_loop(){
  char * buffer = malloc(1024 * 1024);
  fact query;

  while(1){
    printf("?- ");
    if(fgets(buffer, 1024 * 1024 - 1, stdin) == NULL)
      break;

    char * s = trim(buffer);
    int parse_res = parse_fact(s, &query);
    switch(parse_res) {
      case -1:
        printf("Parse error\n");
      case 0:
        continue;
    }

    if (eval_fact(&query) == 1)
      printf("\nyes\n");
    else
      printf("\nno\n");
  }
  free(buffer);
}

static char * trim(char * s) {
  while(*s == ' ' || *s == '\t' || *s == '\n')
    ++s;

  char * ret = s;
  int len = strlen(s);
  for (int i = len - 1; i >= 0; --i)
    if (s[i] == ' ' || s[i] == '\t' || s[i] == '\n' || s[i] == '\r')
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
static int _parse_term(char * s, term * a);
static int parse_term(char * s, term * a) {
  s = trim(s);

  if(strcmp(s, "_") == 0) {
    a->type = any;
    return 1;
  }

  char args[10][100];
  int args_idx = 0;

  int len = strlen(s);
  int start = -1;
  int depth = 0;
  for(int i = 0; i < len; ++i) {
    switch(s[i]) {
      case ' ':
        break;
      case '(':
        ++depth;
        break;
      case ')':
        --depth;
        if (depth == 0) {
          memcpy(args[args_idx], s + start, i + 1 - start);
          args[args_idx][i + 1 - start] = 0;
          args_idx++;
          start = -1;
        }
        break;
      case ',':
        if (depth == 0 && start != -1) {
          memcpy(args[args_idx], s + start, i - start);
          args[args_idx][i - start] = 0;
          args_idx++;
          start = -1;
        }
        break;
      default:
        if(start == -1)
          start = i;
    }
  }

  if (start != -1) {
    memcpy(args[args_idx], s + start, len - start);
    args[args_idx][len - start] = 0;
    args_idx++;
  }

  if (args_idx <= 0)
    return 0;

  if (args_idx == 1) {
    // simple single term
    return _parse_term(args[0], a);
  }

  a->type = expr;
  a->value = malloc(sizeof(functor));
  functor * f = (functor *)a->value;
  strcpy(f->name, "$and");

  for (int i = 0; i < args_idx; ++i){
    if(!_parse_term(args[i], &f->args[f->arity++]))
      return 0;
  }

  return 1;
}

static int _parse_term(char * s, term * a) {
  s = trim(s);

  int low_limit = index_of(s, '(');
  if (low_limit < 1) {
    if (s[0] >= 'A' && s[0] <= 'Z') {
      a->type = variable;
      int len = strlen(s);
      a->variable_name = malloc(len + 1);
      memcpy(a->variable_name, s, len);
      ((char * )a->variable_name)[len] = 0;
      a->value = NULL;
      return 1;
    } else {
      a->type = (s[0] >= '0' && s[0] <= '9') ? constant_number : constant_atom;
      int len = strlen(s);
      a->value = malloc(len + 1);
      memcpy(a->value, s, len);
      ((char * )a->value)[len] = 0;
      a->variable_name = NULL;
      return 1;
    }
  }

  if (s[0] >= 'A' && s[0] <= 'Z')
    return 0;

  a->type = expr;
  a->value = malloc(sizeof(functor));
  return parse_functor(s, (functor *)a->value);
}

static int parse_functor(char * s, functor * f) {
  int len = strlen(s);
  int low_limit = index_of(s, '(');
  if (low_limit < 1 || s[len - 1] != ')')
    return 0;

  memcpy(f->name, s, low_limit);
  f->name[low_limit] = 0;
  f->arity = 0;

  if(s[low_limit + 1] == ')') {
    return 1;
  }

  s[len - 1] = 0;
  s = s + low_limit + 1;

  char * saveptr = NULL;
  while(1) {
    char * arg_str = strtok_r(s, ",", &saveptr);
    s = NULL;
    if (arg_str == NULL)
      break;
    if (parse_term(arg_str, &f->args[f->arity])){
      f->arity++;
    }
  }

  return 1;
}

static void print_functor(functor * f);
static void print_term(term * a) {
  switch(a->type){
    case constant_atom:
      printf("c:%s", (char *)a->value);
      break;
    case constant_number:
      printf("i:%s", (char *)a->value);
      break;
    case expr:
      print_functor((functor *)a->value);
      break;
    case variable:
      printf("v:%s", a->variable_name);
      if (a->value != NULL)
        printf("=%s\n", (char *)a->value);
      break;
    case any:
      printf("v:_");
      break;
  }
}

static void print_functor(functor * f) {
  printf("f:%s", f->name);
  printf("(");
  if (f->arity > 0) {
    for (int i = 0; i < f->arity; ++i){
      if (i != 0)
        printf(",");

      print_term(&f->args[i]);
    }
  }
  printf(")");
}


static void print_fact(fact * f) {
  print_functor(&f->func);
  printf(" :- ");
  print_term(&f->condition);

  printf("\n\n");
}

// Returns 1 on success, 0 on ignored, -1 on error
static int parse_fact(char * fact_line, fact * new_fact) {
  fact_line = trim(fact_line);
  cut_string_at(fact_line, '%');
  int len = strlen(fact_line);
  if (len == 0)
    return 0;


  if (fact_line[len - 1] == '.')
    fact_line[len - 1] = 0;
  else
    return -1;

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

  int is_functor = parse_functor(fact_line1, &new_fact->func);
  if (is_functor) {
    if (!parse_term(fact_line2, &new_fact->condition))
      return -1;
    print_fact(new_fact);
    return 1;
  }

  return -1;
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
  fact new_fact;
  while(1) {
    char * line = strtok_r(buffer_ptr, "\n\r", &saveptr);
    buffer_ptr = NULL;
    if (line == NULL)
      break;


    int parse_result = parse_fact(line, &new_fact);
    if(parse_result < 0){
      printf("Parse error.\n");
      free(buffer);
      return 0;
    }

    if (parse_result > 0) {
      knowledge_base[facts] = malloc(sizeof(fact));
      memcpy(knowledge_base[facts], &new_fact, sizeof(fact));
      ++facts;
    }
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
