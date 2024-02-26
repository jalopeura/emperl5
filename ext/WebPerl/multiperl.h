/*
 * Automatically generated file. DO NOT EDIT! (Edit multiperl.PL instead.)
 */

//#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"

void multiperl_init(int argc, char** argv, char** env);
void multiperl_term();

PerlInterpreter* multiperl_create(int argc, char** argv);
int multiperl_destroy(PerlInterpreter* my_perl);

int multiperl_start(PerlInterpreter* my_perl);
