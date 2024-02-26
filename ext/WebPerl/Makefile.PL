use Config;

# NOTE: emar does not seem to handle multiple inputs very well (we get ndefined symbol errors on the additional objects)
#       so we include multiperl.c in WebPerl.xs, and make some changes below (hopefully only temporary)

my @multiperl_options = $Config{usemultiplicity}
	? (
		# make sure changes to multiperl.PL cause multiperl.c to be regenerated (helpful during development)
		# this does not appear to be working...
		depend => {
			'WebPerl.xs' => 'multiperl.c',
			'multiperl.c' => 'xs_init.c',
			'xs_init.c' => 'xs_init',
		},
	) 
	: (
		# if no multiplicity, don't generate the extra PL files (in our case, multiperl.PL)
		PL_FILES => {}
	);

use 5.026;
use ExtUtils::MakeMaker;
WriteMakefile(
	NAME              => 'WebPerl',
	VERSION_FROM      => 'lib/WebPerl.pm',
	AUTHOR            => 'Hauke D <haukex@zero-g.net>',
	LICENSE           => 'perl',
	INC               => '-I.',
	CCFLAGS           => '-fPIC',
	@multiperl_options,
);
