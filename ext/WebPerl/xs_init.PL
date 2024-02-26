use strict;

my $basename = $ARGV[0];

# we need the xsinit from perlmain.c

# this is intended to be compiled as part of a static extension,
# so it will be compiled with perl, and in the folder ext/EXTENTION_NAME,
# so we know where perlmain.c will be
open PERLMAIN, '../../perlmain.c' or die "Unable to read perlmain.c: $!";
my $perlmain = join('', <PERLMAIN>);
close PERLMAIN;

my ($xsinit) = $perlmain=~m{(/\* Register any extra external extensions \*/.+)$}s;

open C, ">$basename.inc" or die "Unable to create source file: $!";

print C <<SOURCE;
/*
 * Automatically generated file. DO NOT EDIT! (Edit $0 instead.)
 */

// copied from perlmain.c
$xsinit
SOURCE

close C;

__END__

// hard-coded for now; later copy it from elsewhere

/* Register any extra external extensions */

EXTERN_C void boot_DynaLoader (pTHX_ CV* cv);
EXTERN_C void boot_attributes (pTHX_ CV* cv);
EXTERN_C void boot_B (pTHX_ CV* cv);
EXTERN_C void boot_Cwd (pTHX_ CV* cv);
EXTERN_C void boot_Data__Dumper (pTHX_ CV* cv);
EXTERN_C void boot_Devel__Peek (pTHX_ CV* cv);
EXTERN_C void boot_Digest__MD5 (pTHX_ CV* cv);
EXTERN_C void boot_Digest__SHA (pTHX_ CV* cv);
EXTERN_C void boot_Encode (pTHX_ CV* cv);
EXTERN_C void boot_Fcntl (pTHX_ CV* cv);
EXTERN_C void boot_File__Glob (pTHX_ CV* cv);
EXTERN_C void boot_Hash__Util (pTHX_ CV* cv);
EXTERN_C void boot_I18N__Langinfo (pTHX_ CV* cv);
EXTERN_C void boot_IO (pTHX_ CV* cv);
EXTERN_C void boot_List__Util (pTHX_ CV* cv);
EXTERN_C void boot_mro (pTHX_ CV* cv);
EXTERN_C void boot_Opcode (pTHX_ CV* cv);
EXTERN_C void boot_PerlIO__encoding (pTHX_ CV* cv);
EXTERN_C void boot_PerlIO__scalar (pTHX_ CV* cv);
EXTERN_C void boot_PerlIO__via (pTHX_ CV* cv);
EXTERN_C void boot_POSIX (pTHX_ CV* cv);
EXTERN_C void boot_SDBM_File (pTHX_ CV* cv);
EXTERN_C void boot_Socket (pTHX_ CV* cv);
EXTERN_C void boot_Time__HiRes (pTHX_ CV* cv);
EXTERN_C void boot_Time__Piece (pTHX_ CV* cv);
EXTERN_C void boot_Unicode__Normalize (pTHX_ CV* cv);
EXTERN_C void boot_WebPerl (pTHX_ CV* cv);
EXTERN_C void boot_Cpanel__JSON__XS (pTHX_ CV* cv);
EXTERN_C void boot_Storable (pTHX_ CV* cv);
EXTERN_C void boot_Compress__Raw__Zlib (pTHX_ CV* cv);
EXTERN_C void boot_DBI (pTHX_ CV* cv);
EXTERN_C void boot_DBD__SQLite (pTHX_ CV* cv);
EXTERN_C void boot_Encode__Byte (pTHX_ CV* cv);
EXTERN_C void boot_Encode__Symbol (pTHX_ CV* cv);
EXTERN_C void boot_Encode__Unicode (pTHX_ CV* cv);

static void
xs_init(pTHX)
{
    static const char file[] = __FILE__;
    dXSUB_SYS;
    PERL_UNUSED_CONTEXT;

    /* DynaLoader is a special case */
    newXS("DynaLoader::boot_DynaLoader", boot_DynaLoader, file);
    newXS("attributes::bootstrap", boot_attributes, file);
    newXS("B::bootstrap", boot_B, file);
    newXS("Cwd::bootstrap", boot_Cwd, file);
    newXS("Data::Dumper::bootstrap", boot_Data__Dumper, file);
    newXS("Devel::Peek::bootstrap", boot_Devel__Peek, file);
    newXS("Digest::MD5::bootstrap", boot_Digest__MD5, file);
    newXS("Digest::SHA::bootstrap", boot_Digest__SHA, file);
    newXS("Encode::bootstrap", boot_Encode, file);
    newXS("Fcntl::bootstrap", boot_Fcntl, file);
    newXS("File::Glob::bootstrap", boot_File__Glob, file);
    newXS("Hash::Util::bootstrap", boot_Hash__Util, file);
    newXS("I18N::Langinfo::bootstrap", boot_I18N__Langinfo, file);
    newXS("IO::bootstrap", boot_IO, file);
    newXS("List::Util::bootstrap", boot_List__Util, file);
    newXS("mro::bootstrap", boot_mro, file);
    newXS("Opcode::bootstrap", boot_Opcode, file);
    newXS("PerlIO::encoding::bootstrap", boot_PerlIO__encoding, file);
    newXS("PerlIO::scalar::bootstrap", boot_PerlIO__scalar, file);
    newXS("PerlIO::via::bootstrap", boot_PerlIO__via, file);
    newXS("POSIX::bootstrap", boot_POSIX, file);
    newXS("SDBM_File::bootstrap", boot_SDBM_File, file);
    newXS("Socket::bootstrap", boot_Socket, file);
    newXS("Time::HiRes::bootstrap", boot_Time__HiRes, file);
    newXS("Time::Piece::bootstrap", boot_Time__Piece, file);
    newXS("Unicode::Normalize::bootstrap", boot_Unicode__Normalize, file);
    newXS("WebPerl::bootstrap", boot_WebPerl, file);
    newXS("Cpanel::JSON::XS::bootstrap", boot_Cpanel__JSON__XS, file);
    newXS("Storable::bootstrap", boot_Storable, file);
    newXS("Compress::Raw::Zlib::bootstrap", boot_Compress__Raw__Zlib, file);
    newXS("DBI::bootstrap", boot_DBI, file);
    newXS("DBD::SQLite::bootstrap", boot_DBD__SQLite, file);
    newXS("Encode::Byte::bootstrap", boot_Encode__Byte, file);
    newXS("Encode::Symbol::bootstrap", boot_Encode__Symbol, file);
    newXS("Encode::Unicode::bootstrap", boot_Encode__Unicode, file);
}
