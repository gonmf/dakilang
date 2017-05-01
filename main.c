#define _POSIX_C_SOURCE 199309L
#define _XOPEN_SOURCE 600

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define MAX_FACT_VARIABLES 20
#define MAX_FACTS 100
#define MAX_FUNCTOR_ARGUMENTS 20

static char * built_in_funcs[] = { "eq/", "and/2", "or/2", "xor/2", "not/1", "listing/0", "write/1", "print/1", "nl/0", "halt/0", NULL };

typedef enum __expr_type_ {
  constant,
  func_type,
  variable,
  var_any,
} expr_type;

typedef struct __term_ {
  expr_type type;
  void * value;
} term;

typedef struct __functor_ {
  char * name;
  int arity;
  term args[MAX_FUNCTOR_ARGUMENTS];
} functor;

typedef struct __var_list_ {
  char * name[MAX_FACT_VARIABLES];
  expr_type type[MAX_FACT_VARIABLES];
  void * value[MAX_FACT_VARIABLES];
  int public[MAX_FACT_VARIABLES];
} var_list;

typedef struct __fact_ {
  functor func;
  term condition;
  var_list vars;
} fact;

static fact * knowledge_base[MAX_FACTS];
static int debug = 0;

static int reserved_name(const char * name) {
  for(int i = 0; built_in_funcs[i] != NULL; ++i)
    if (strcmp(name, built_in_funcs[i]) == 0)
      return 1;
  return 0;
}

static void print_term(term * a);
static int is_unset_var(var_list * vars, term * t) {
  if (t->type != variable && t->type != var_any)
    return 0;

  char * name = (char *)t->value;
  for (int i = 0; vars->name[i] != NULL; ++i) {
    if (strcmp(vars->name[i], name) == 0) {
      if (vars->value[i] == NULL) {
        return 1;
      }
      return 0;
    }
  }

  // Var not in this var list
  return 1;
}

static void set_var(var_list * vars, char * name, void * value, expr_type type) {
  int i;
  for (i = 0; vars->name[i] != NULL; ++i) {
    if (strcmp(vars->name[i], name) == 0) {
      vars->name[i] = name;
      vars->type[i] = type;
      vars->value[i] = value;
      vars->public[i] = 1;
      return;
    }
  }

  vars->name[i] = name;
  vars->type[i] = type;
  vars->value[i] = value;
  vars->public[i] = 0;
}

static void unset_var(var_list * vars, char * name) {
  for (int i = 0; vars->name[i] != NULL; ++i) {
    if (strcmp(vars->name[i], name) == 0) {
      vars->value[i] = NULL;
      return;
    }
  }

  exit(EXIT_FAILURE);
}

static int eval_functor(functor * f, var_list * vars);
static int eval_term(term * t, var_list * vars) {
  char * val;

  switch (t->type) {
    case constant:
      val = (char *)t->value;
      return strcmp(val, "0") != 0;
    case func_type:
      return eval_functor((functor *)t->value, vars);
    case variable:
      return 1;
    case var_any:
      return 1;
  }

  exit(EXIT_FAILURE);
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

static void print_fact(fact * f);
static int eval_functor(functor * f, var_list * vars) {
  if (strcmp(f->name, "eq/2") == 0) {
    if (final_type(&f->args[0], vars) != final_type(&f->args[1], vars))
      return 0;

    return (strcmp(f->args[0].value, f->args[1].value) == 0);
  }

  if (strcmp(f->name, "and/2") == 0) {
    return (eval_term(&f->args[0], vars) && eval_term(&f->args[1], vars)) ? 1 : 0;
  }

  if (strcmp(f->name, "or/2") == 0) {
    return (eval_term(&f->args[0], vars) || eval_term(&f->args[1], vars)) ? 1 : 0;
  }

  if (strcmp(f->name, "xor/2") == 0) {
    return (eval_term(&f->args[0], vars) != eval_term(&f->args[1], vars)) ? 1 : 0;
  }

  if (strcmp(f->name, "not/1") == 0) {
    return eval_term(&f->args[0], vars) ? 0 : 1;
  }

  if (strcmp(f->name, "listing/0") == 0) {
    for (int i = 0; knowledge_base[i] != NULL; ++i) {
      print_fact(knowledge_base[i]);
    }
    return 1;
  }

  if (strcmp(f->name, "write/1") == 0 || strcmp(f->name, "print/1") == 0) {
    term * t = &f->args[0];
    if (t->type == func_type)
      printf("%s", ((functor *)t->value)->name);
    else
      printf("%s", (char *)t->value);
    return 1;
  }

  if (strcmp(f->name, "nl/0") == 0) {
    printf("\n");
    return 1;
  }

  if (strcmp(f->name, "halt/0") == 0) {
    exit(EXIT_FAILURE);
    return 0;
  }

  int method_name_found = 0;
  for(int i = 0; knowledge_base[i] != NULL; ++i) {
    fact * my_fact = knowledge_base[i];

    functor * saved = &my_fact->func;
    if (strcmp(saved->name, f->name) == 0) {
      method_name_found = 1;
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

          if (is_unset_var(vars, &saved->args[j]) && f->args[j].type != variable) {
            set_var(vars, (char *)saved->args[j].value, f->args[j].value, f->args[j].type);
            if (eval_functor(f, vars)) {
              return 1;
            }
            unset_var(vars, (char *)saved->args[j].value);
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

  if (!method_name_found)
    printf("%% Definition \"%s\" not found.\n", f->name);

  return 0;
}

static int eval_fact(fact * f) {
  if (eval_term(&f->condition, &f->vars) && eval_functor(&f->func, &f->vars)) {
    int found = 0;
    for (int i = 0; f->vars.name[i] != NULL; ++i) {
      if (f->vars.public[i]) {
        found++;
        if (f->vars.value[i] == NULL)
          printf("%s = (any)\n", f->vars.name[i]);
        else
          printf("%s = %s\n", f->vars.name[i], (char *)f->vars.value[i]);
      }
    }
    if (found > 0)
      printf("\n");
    return 1;
  }
  return 0;
}

static char * trim(char * s);
static int parse_fact(char * fact_line, fact * new_fact);
static void main_loop(){
  char * buffer = calloc(1, 1024 * 1024);
  fact query;

  while(1){
    printf("?- ");
    if(fgets(buffer, 1024 * 1024 - 1, stdin) == NULL)
      break;

    printf("\n");

    char * s = trim(buffer);
    int parse_res = parse_fact(s, &query);
    switch(parse_res) {
      case -1:
        printf("%% Parse error.\n\n");
      case 0:
        continue;
    }

    int res = eval_fact(&query);
    if (res == 1)
      printf("yes\n\n");
    else
      printf("no\n\n");
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

  char args[MAX_FUNCTOR_ARGUMENTS][100];
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
  f->name = calloc(1, 6);
  strcpy(f->name, "and/2");

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
        vars->public[i] = 1;
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
      a->type = constant;
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
  if (s[0] < 'a' || s[0] > 'z') {
    return 0;
  }

  f->arity = 0;

  int len = strlen(s);
  int low_limit = index_of(s, '(');
  if (low_limit >= 1 && s[len - 1] == ')') {
    char * args_str = s + low_limit + 1;
    s[low_limit] = 0;
    args_str[strlen(args_str) - 1] = 0;

    char * saveptr = NULL;
    while(1) {
      char * arg_str = strtok_r(args_str, ",", &saveptr);
      args_str = NULL;
      if (arg_str == NULL)
        break;
      if (parse_term(arg_str, &f->args[f->arity], vars)) {
        f->arity++;
      } else {
        return 0;
      }
    }

  }

  int limit = strlen(s) + 4;
  f->name = calloc(1, limit);
  snprintf(f->name, limit, "%s/%d", s, f->arity);
  return 1;
}

static void print_functor(functor * f);
static void print_term(term * a) {
  switch(a->type){
    case constant:
      printf("c:%s", (char *)a->value);
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
    default:
      printf("%% Error printing term.\n");
      exit(EXIT_FAILURE);
  }
}

static void print_functor(functor * f) {
  printf("f:%s", f->name);
  if (f->arity == 0)
    return;

  printf("(");
  for (int i = 0; i < f->arity; ++i){
    if (i != 0)
      printf(",");

    print_term(&f->args[i]);
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

  cut_string_at(fact_line, '%');
  fact_line = trim(fact_line);
  int len = strlen(fact_line);
  if (len == 0)
    return 0;

  if (fact_line[len - 1] == '.') {
    fact_line[len - 1] = 0;
  } else
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
    if (debug)
      print_fact(new_fact);
    return 1;
  }

  return -1;
}

static int eval_file(const char * file_name){
  printf("%% Evaluating \"%s\"...\n\n", file_name);

  char * buffer = calloc(1, 1024 * 1024);

  FILE * fp = fopen(file_name, "r");
  if (fp == NULL) {
    free(buffer);
    printf("%% File not found.");
    return 0;
  }

  int r = (int)fread(buffer, 1, 1024 * 1024, fp);
  int err = ferror(fp);
  fclose(fp);

  if (err || r <= 0) {
      free(buffer);
      return 0;
  }

  buffer[r] = 0;

  char * buffer_ptr = buffer;
  char * saveptr = NULL;
  int last_result = 1;
  fact new_fact;
  while(1) {
    char * line = strtok_r(buffer_ptr, "\n\r", &saveptr);
    buffer_ptr = NULL;
    if (line == NULL)
      break;

    printf("?- %s\n\n", line);

    int parse_result = parse_fact(line, &new_fact);
    if(parse_result < 0){
      printf("%% Parse error.\n");
      continue;
    }

    if (reserved_name(new_fact.func.name)) {
      printf("%% Reserved name error.\n");
      continue;
    }

    if (parse_result > 0)
      last_result = eval_fact(&new_fact);

      if (last_result == 1)
        printf("yes\n\n");
      else
        printf("no\n\n");
  }

  return last_result;
}

static int consult(const char * file_name){
  printf("%% Consulting \"%s\"...\n\n", file_name);

  char * buffer = calloc(1, 1024 * 1024);

  FILE * fp = fopen(file_name, "r");
  if (fp == NULL) {
    free(buffer);
    printf("%% File not found.");
    return 0;
  }

  int r = (int)fread(buffer, 1, 1024 * 1024, fp);
  int err = ferror(fp);
  fclose(fp);

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
      printf("%% Parse error.\n");
      free(buffer);
      return 0;
    }

    if (parse_result > 0) {
      knowledge_base[facts] = calloc(1, sizeof(fact));
      memcpy(knowledge_base[facts], &new_fact, sizeof(fact));
      ++facts;
    }
  }

  printf("%% Loaded %d facts.\n\n", facts);

  return 1;
}

static void print_usage(const char * program_name){
  printf("%s [knowledge_base]\n\n", program_name);
}

int main(int argc, char * argv[]){
  for (int i = 1; i < argc; ++i) {
    if (strcmp(argv[i], "--debug") == 0) {
      debug = 1;
      break;
    }
  }

  for (int i = 1; i < argc - 1; ++i) {
    if (strcmp(argv[i], "--consult") == 0) {
      char * file_name = argv[i + 1];
      if(!consult(file_name))
        return EXIT_FAILURE;
      break;
    }
  }

  for (int i = 1; i < argc - 1; ++i) {
    if (strcmp(argv[i], "--eval") == 0) {
      char * file_name = argv[i + 1];
      if (eval_file(file_name))
        return EXIT_SUCCESS;
      return EXIT_FAILURE;
    }
  }

  main_loop();
  return EXIT_SUCCESS;
}
