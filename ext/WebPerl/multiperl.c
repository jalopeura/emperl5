/*
 * Automatically generated file. DO NOT EDIT! (Edit multiperl.PL instead.)
 */

#include "multiperl.h"
//#include "XSUB.h"

#include "xs_init.inc"

/*
 * you must call this:
 *   just once
 *   before creating any interpreters
 *   from main (is this really true? I guess we'll find out)
 *   with the same arguments passed to main
 *    (if your main doesn't take env, you can pass (char**)NULL)
 */
void
multiperl_init(int argc, char **argv, char **env)
{
	/* if user wants control of gprof profiling off by default */
	/* noop unless Configure is given -Accflags=-DPERL_GPROF_CONTROL */
	PERL_GPROF_MONCONTROL(0);

	PERL_SYS_INIT3(&argc,&argv,&env);
}

/*
 * you must call this:
 *   just once
 *   after destroying all interpreters
 */
void
multiperl_term()
{
	PERL_SYS_TERM();
}


/*
 * the arguments here don't have to be the ones passed to main()
 */
PerlInterpreter*
multiperl_create(int argc, char** argv)
{
	PerlInterpreter* my_perl = perl_alloc();

	if (! my_perl) {
		perl_free(my_perl);
		return NULL;
	}

	PL_perl_destruct_level = 1;
	perl_construct(my_perl);

	if (perl_parse(my_perl, xs_init, argc, argv, (char**)NULL))
		return NULL;

	/* perl_parse() may end up starting its own run loops, which
	 * might end up "leaking" PL_restartop from the parse phase into
	 * the run phase which then ends up confusing run_body(). This
	 * leakage shouldn't happen and if it does its a bug.
	 *
	 * Note we do not do this assert in perl_run() or perl_parse()
	 * as there are modules out there which explicitly set
	 * PL_restartop before calling perl_run() directly from XS code
	 * (Coro), and it is conceivable PL_restartop could be set prior
	 * to calling perl_parse() by XS code as well.
	 *
	 * What we want to check is that the top level perl_parse(),
	 * perl_run() pairing does not allow a leaking PL_restartop, as
	 * that indicates a bug in perl. By putting the assert here we
	 * can validate that Perl itself is operating correctly without
	 * risking breakage to XS code under DEBUGGING. - Yves
	 */
	assert(!PL_restartop);

	return my_perl;
}


int
multiperl_destroy(PerlInterpreter* my_perl)
{
#ifndef PERL_MICRO
	/* Unregister our signal handler before destroying my_perl */
	for (int i = 1; PL_sig_name[i]; i++) {
	if (rsignal_state(PL_sig_num[i]) == (Sighandler_t) PL_csighandlerp) {
		rsignal(PL_sig_num[i], (Sighandler_t) SIG_DFL);
	}
	}
#endif

	PL_perl_destruct_level = 1;
	int exitstatus = perl_destruct(my_perl);

	perl_free(my_perl);

	return exitstatus;
}


int
multiperl_start(PerlInterpreter* my_perl)
{
	return perl_run(my_perl);
}
