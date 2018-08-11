# Uncomment this line to compile in macOS, having previously installed
# clang-omp through brew.
# CC := clang-omp

# If your system includes a clang with OpenMP 3.0 support
# CC := clang

CFLAGS := -std=c99 -O2 -Wall -Wextra -Wformat=2 -pedantic-errors \
          -Wfatal-errors -Wundef -Wno-unused-result -march=native

LDFLAGS += -lm

# For debugging add -g to CFLAGS
CFLAGS += -g

# GCC > 4.9 only
CFLAGS += -fdiagnostics-color=auto

SRCFILES := $(wildcard *.c)

OBJFILES := $(patsubst %.c,%.o,$(SRCFILES))

DEPFILES := $(patsubst %.o,%.d,$(OBJFILES))

PROGRAMS := prolog

.PHONY: $(PROGRAMS) clean

all: $(PROGRAMS)

prolog: $(OBJFILES)
	@$(CC) $^ $(CFLAGS) $(LDFLAGS) -o $@

%.o: %.c
	@$(CC) -c -o $@ $< $(CFLAGS)

-include $(DEPFILES)

tidy:
	@$(RM) -f prolog *.o *.d

clean: tidy
	@$(RM) -f $(PROGRAMS)
