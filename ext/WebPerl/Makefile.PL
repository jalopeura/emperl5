use 5.026;
use ExtUtils::MakeMaker;
WriteMakefile(
	NAME              => 'WebPerl',
	VERSION_FROM      => 'lib/WebPerl.pm',
	AUTHOR            => 'Hauke D <haukex@zero-g.net>',
	LICENSE           => 'perl',
	INC               => '-I.',
	CCFLAGS           => '-fPIC',
);
