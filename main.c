#define _POSIX_C_SOURCE 199309L
#define _XOPEN_SOURCE 600

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_FACTS 100

typedef enum __expr_type_ {
  const_atom,
  const_num,
  func_type,
  variable,
  var_any,
} expr_type;

typedef struct __term_ {
  expr_type type;
  void * value;
} term;

typedef struct __functor_ {
  char name[32];
  int arity;
  term args[10];
} functor;

typedef struct __var_list_ {
  char * name[64];
  expr_type type[64];
  void * value[64];
} var_list;

typedef struct __fact_ {
  functor func;
  term condition;
  var_list vars;
} fact;

static fact * knowledge_base[MAX_FACTS];

static int is_unset_var(var_list * vars, term * t) {
  if (t->type != variable && t->type != var_any)
    return 0;

  char * name = (char *)t->value;
  for (int i = 0; ; ++i) {
    if (strcmp(vars->name[i], name) == 0) {
      if (vars->value[i] == NULL) {
        return 1;
      }
      return 0;
    }
  }

  exit(EXIT_FAILURE);
}

static void set_var(var_list * vars, char * name, void * value, expr_type type) {
  for (int i = 0; ; ++i) {
    if (strcmp(vars->name[i], name) == 0) {
      vars->name[i] = name;
      vars->type[i] = type;
      vars->value[i] = value;
      return;
    }
  }

  exit(EXIT_FAILURE);
}

static void unset_var(var_list * vars, char * name) {
  for (int i = 0; ; ++i) {
    if (strcmp(vars->name[i], name) == 0) {
      vars->value[i] = NULL;
      return;
    }
  }

  exit(EXIT_FAILURE);
}

static int eval_term(term * t, var_list * vars) {
  return 1;
}

static expr_type final_type(term * t, var_list * vars) {
  if (t->type != variable)
    return t->type;

  for (int i = 0; ; ++i) {
    if (strcmp(vars->name[i], t->value) == 0) {
      if (vars->value[i] != NULL) {
        return vars->type[i];
      }

      return variable;
    }
  }

  exit(EXIT_FAILURE);
}

static void * final_value(term * t, var_list * vars) {
  if (t->type != variable)
    return t->value;

  for (int i = 0; ; ++i) {
    if (strcmp(vars->name[i], t->value) == 0)
      return vars->value[i];
  }

  exit(EXIT_FAILURE);
}

static int eval_functor(functor * f, var_list * vars) {
  int i = 0;
  while(knowledge_base[i] != NULL) {
    fact * my_fact = knowledge_base[i++];

    functor * saved = &my_fact->func;
    if (strcmp(saved->name, f->name) == 0 && f->arity == saved->arity) {
      if (eval_term(&my_fact->condition, vars)){
        for(int j = 0; j < saved->arity; ++j) {
          if (is_unset_var(vars, &saved->args[j]) && is_unset_var(vars, &f->args[j])) {
            continue;
          }

          if (saved->args[j].type != variable && is_unset_var(vars, &f->args[j])) {
            set_var(vars, (char *)f->args[j].value, saved->args[j].value, saved->args[j].type);
            if (eval_functor(f, vars)) {
              return 1;
            }
            unset_var(vars, (char *)f->args[j].value);
            return 0;
          }

          if (final_type(&saved->args[j], vars) != final_type(&f->args[j], vars)) {
            return 0;
          }

          if (strcmp((char *)final_value(&saved->args[j], vars), (char *)final_value(&f->args[j], vars)) != 0) {
            return 0;
          }
        }

        return 1;
      }
    }
  }

  return 0;
}

static int eval_fact(fact * f) {
  if (eval_term(&f->condition, &f->vars) && eval_functor(&f->func, &f->vars)) {
    for (int i = 0; f->vars.name[i] != NULL; ++i) {
      if (f->vars.value[i] == NULL)
        printf("%s = (any)\n", f->vars.name[i]);
      else
        printf("%s = %s\n", f->vars.name[i], (char *)f->vars.value[i]);
    }
    return 1;
  }
  return 0;
}

static void print_fact(fact * f);
static char * trim(char * s);
static int parse_fact(char * fact_line, fact * new_fact);
static void main_loop(){
  char * buffer = calloc(1, 1024 * 1024);
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

static int parse_functor(char * s, functor * f, var_list * vars);
static int _parse_term(char * s, term * a, var_list * vars);
static int parse_term(char * s, term * a, var_list * vars) {
  s = trim(s);

  if(strcmp(s, "_") == 0) {
    a->type = var_any;
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
    return _parse_term(args[0], a, vars);
  }

  a->type = func_type;
  a->value = calloc(1, sizeof(functor));
  functor * f = (functor *)a->value;
  strcpy(f->name, "$and");

  for (int i = 0; i < args_idx; ++i){
    if(!_parse_term(args[i], &f->args[f->arity++], vars))
      return 0;
  }

  return 1;
}

static void var_list_init(var_list * vars, char * name) {
  int i = 0;
    while(1) {
      if (vars->name[i] == NULL) {
        vars->name[i] = name;
        vars->value[i] = NULL;
        vars->name[i + 1] = NULL;
        return;
      }
      if (strcmp(vars->name[i], name) == 0)
        return;
      ++i;
    }
}

static int _parse_term(char * s, term * a, var_list * vars) {
  s = trim(s);

  int low_limit = index_of(s, '(');
  if (low_limit < 1) {
    if (s[0] >= 'A' && s[0] <= 'Z') {
      a->type = variable;
    } else {
      a->type = (s[0] >= '0' && s[0] <= '9') ? const_num : const_atom;
    }
    int len = strlen(s);
    a->value = calloc(1, len + 1);
    memcpy(a->value, s, len);
    ((char * )a->value)[len] = 0;

    if(a->type == variable)
      var_list_init(vars, a->value);
    return 1;
  }

  if (s[0] >= 'A' && s[0] <= 'Z')
    return 0;

  a->type = func_type;
  a->value = calloc(1, sizeof(functor));
  return parse_functor(s, (functor *)a->value, vars);
}

static int parse_functor(char * s, functor * f, var_list * vars) {
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
    if (parse_term(arg_str, &f->args[f->arity], vars)) {
      f->arity++;
    }
  }

  return 1;
}

static void print_functor(functor * f);
static void print_term(term * a) {
  switch(a->type){
    case const_atom:
      printf("c:%s", (char *)a->value);
      break;
    case const_num:
      printf("i:%s", (char *)a->value);
      break;
    case func_type:
      print_functor((functor *)a->value);
      break;
    case variable:
      printf("v:%s", (char *)a->value);
      break;
    case var_any:
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
  memset(new_fact, 0, sizeof(fact));

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

  int is_functor = parse_functor(fact_line1, &new_fact->func, &new_fact->vars);
  if (is_functor) {
    if (!parse_term(fact_line2, &new_fact->condition, &new_fact->vars))
      return -1;
    print_fact(new_fact);
    return 1;
  }

  return -1;
}

static int consult(const char * file_name){
  char * buffer = calloc(1, 1024 * 1024);

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
      knowledge_base[facts] = calloc(1, sizeof(fact));
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
