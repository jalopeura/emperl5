package WebPerl;
use 5.026;
use warnings;
use Carp;
use Cpanel::JSON::XS qw/encode_json/;
use Scalar::Util qw/blessed refaddr/;
use Sub::Util qw/subname/;
use Data::Dumper ();

=head1 SYNOPSIS

 use WebPerl qw/js/;
 js(q{ alert("I am JavaScript!"); });

Please see the documentation at L<http://webperl.zero-g.net/using.html>!

=head1 Author, Copyright, and License

B<< WebPerl - L<http://webperl.zero-g.net> >>

Copyright (c) 2018 Hauke Daempfling (haukex@zero-g.net)
at the Leibniz Institute of Freshwater Ecology and Inland Fisheries (IGB),
Berlin, Germany, L<http://www.igb-berlin.de>

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl 5 itself: either the GNU General Public
License as published by the Free Software Foundation (either version 1,
or, at your option, any later version), or the "Artistic License" which
comes with Perl 5.

This program is distributed in the hope that it will be useful, but
B<WITHOUT ANY WARRANTY>; without even the implied warranty of
B<MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE>.
See the licenses for details.

You should have received a copy of the licenses along with this program.
If not, see L<http://perldoc.perl.org/index-licence.html>.

=cut

our $VERSION = '0.11'; # v0.11-beta

require XSLoader;
XSLoader::load('WebPerl', $VERSION);

use Exporter 'import';
our @EXPORT_OK = qw/ js encode_json unregister sub_once sub1 js_new /;

our $JSON = Cpanel::JSON::XS->new->allow_nonref;
our $TRACE = 0;

STDOUT->autoflush(1); # assume the user will always want this

sub _perlstr {
	confess "bad nr of args" unless @_==1;
	my $str = shift;
	croak "can only be used on scalars" if ref $str;
	state $dumper = Data::Dumper->new([])->Useqq(1)->Terse(1)->Indent(0)->Purity(1);
	return $dumper->Reset->Values([$str])->Dump;
}

sub js {
	croak "incorrect number of arguments to js()" unless @_==1;
	my $code = shift;
	return undef if !defined $code; # pass thru without calling JS
	if (my $r = ref $code) {
		if ($r eq 'HASH' || $r eq 'ARRAY' || $r eq 'CODE')
			{ $code = '('._to_js($code).')' }
		else { croak "unsupported argument to js()" }
	}
	$TRACE and say STDERR "js(",_perlstr($code),")";
	carp "js: non-ASCII characters in non-UTF-8 string" #TODO Later: compare to how $JSON->encode() handles this
		if !utf8::is_utf8($code) && $code=~/[\x80-\xFF]/aa;
	my $rv = xs_eval_js($code, defined wantarray ? 1 : 0);
	my $type = chop($rv);
	   if ($type eq 'U') { return undef }
	elsif ($type eq 'B') { return !!$rv }
	elsif ($type eq 'N') { return 0+$rv }
	elsif ($type eq 'S') { return $rv }
	elsif ($type eq 'E') { croak "JS Error: $rv" }
	elsif ($type eq 'F' || $type eq 'A' || $type eq 'O') {
		return bless { type => $type, id => $rv }, 'WebPerl::JSObject';
	}
	elsif ($type eq 'X') { # e.g. "symbol", which we don't (yet) support
		carp "unsupported return type from JS: $rv";
		return undef }
	confess "js() internal error: $rv";
}

sub _my_subkey { sprintf("%06x",refaddr(shift)) }
our %CodeTable; # table to keep refs to anonymous subs which are passed to JS alive
sub _code_reg {
	my $sub = shift;
	my ($callcode,$is_anon);
	my $name = subname($sub);
	if ($name=~/\b__ANON__\z/) { $is_anon=1 }
	else { # the code ref has a name, check if it's in the symbol table
		my ($pack,$n) = $name=~/^(.+)::(.*?)$/;
		my $st = do { no strict 'refs'; \%{$pack.'::'} };
		if ( exists $st->{$n} && $st->{$n} && *{$st->{$n}}{CODE} && *{$st->{$n}}{CODE}==$sub ) {
			# the code is in the symbol table, so no CodeTable entry needed
			$callcode = "do { no strict 'refs'; \\&{"._perlstr($name)."} }";
		}
		else {
			# the code has a name but it's not what's in the symbol table, treat like anonymous
			# (this can happen for example if the caller used Sub::Util::set_subname on an anonymous sub)
			$is_anon=1;
		}
	}
	if ($is_anon) {
		my $subkey = _my_subkey($sub);
		$TRACE and say STDERR "Perl new code table entry ", _perlstr($subkey);
		$CodeTable{$subkey} = $sub;
		$callcode = _perlstr($subkey);
	}
	return 'Perl.dispatch.bind(null,'
			. perl_context() . ','
			. $JSON->encode( 'WebPerl::_call_code('.$callcode.')' )
		.')';
}
sub _call_code {
	my $code = shift;
	# Handing over arguments via a global JS value is not pretty, but it works for now.
	my @args = js('Perl._call_code_args')->@*;
	js('delete Perl._call_code_args;');
	my $dbname;
	if (my $r = ref $code) {
		confess "_call_code was passed an invalid reference type: $r"
			unless $r eq 'CODE';
		$dbname = _perlstr(subname($code));
	}
	else {
		if (!$CodeTable{$code}) {
			js('Perl._call_code_error='.$JSON->encode("code table entry '$code' does not exist"));
			return;
		}
		$dbname = _perlstr($code);
		$code = $CodeTable{$code};
	}
	$TRACE and say STDERR "Perl call $dbname";
	# Note that @args may contain JSObjects, and @args going out of scope could mean
	# that those objects are deleted from the Perl.GlueTable before the JS has
	# a chance to get to them - that's why we need to copy over the return value
	# to JS here before we exit this sub.
	my $rv;
	if ( eval { $rv = $code->(@args); 1 } )
		{ js('Perl._call_code_rv='._to_js($rv)) }
	else
		{ js('Perl._call_code_error='.$JSON->encode( "Perl code $dbname died: ".( $@ ? $@ : 'unknown error' ) )) }
	return;
}
# "unregister" exists so that anonymous subs passed to JS can do: WebPerl::unregister(__SUB__);
sub unregister {
	croak "bad number of arguments to unregister" unless @_==1;
	my $sub = shift;
	my $subkey = _my_subkey($sub);
	if (exists $CodeTable{$subkey}) {
		$TRACE and say STDERR "Perl unregister code table entry ", _perlstr($subkey);
		delete $CodeTable{$subkey};
	}
	else { carp "attempt to unregister code table entry that doesn't exist: "._perlstr($subkey) }
	return;
}
sub sub_once (&) {
	my $sub = shift;
	return sub {
		if (wantarray) {
			my @rv = $sub->(@_);
			unregister(__SUB__);
			return @rv;
		}
		elsif (defined wantarray) {
			my $rv = $sub->(@_);
			unregister(__SUB__);
			return $rv;
		}
		else {
			$sub->(@_);
			unregister(__SUB__);
			return;
		}
	}
}
*sub1 = *sub1 = \&sub_once;

# It seems that many of the JSON:: modules don't allow hooking so as to be able to output JS "function"s.
# This is my current workaround, encoding the data structures manually... not pretty, but I guess it works.
sub _to_js { #TODO Later: should we provide this to the outside as well? (what for - doesn't js() cover the users' needs?)
	confess "bad nr of args" unless @_==1;
	my $what = shift;
	if (my $r = ref $what) {
		if ($r eq 'HASH') {
			return '{' . join(',',
					map { $JSON->encode("$_").':'._to_js($$what{$_}) } sort keys %$what
				) . '}';
		}
		elsif ($r eq 'ARRAY') {
			return '[' . join(',', map { _to_js($_) } @$what) . ']';
		}
		elsif ($r eq 'CODE')
			{ return _code_reg($what) }
		else {
			if (blessed($what) && $what->isa('WebPerl::JSObject')) {
				#TODO Later: Are there any cases where we might be passing GlueTable entries to JS that are deleted by our JSObject::DESTROY before JS can get to them?
				# (that will depend on all of the places we use _to_js())
				return $what->jscode;
			}
			croak "can't encode ref $r to JS";
		}
	}
	else { return $JSON->encode($what) }
}

sub _to_perl { #TODO: this needs tests
	confess "bad nr of args" unless @_==1;
	my $what = shift;
	if (my $r = ref $what) {
		if ($r eq 'HASH' && tied(%$what) && tied(%$what)->isa('WebPerl::JSObject::TiedHash')) {
			return { map { ( $_ => _to_perl($$what{$_}) ) } keys %$what };
		}
		elsif ($r eq 'ARRAY' && tied(@$what) && tied(@$what)->isa('WebPerl::JSObject::TiedArray')) {
			return [ map { _to_perl($_) } @$what ];
		}
		elsif (blessed($what) && $what->isa('WebPerl::JSObject')) {
			no overloading '%{}';
			if ($what->{type} eq 'F') { # JS Function
				# note we don't just return $what->coderef because that doesn't keep a reference to $what alive
				return sub { $what->coderef->(@_) }
			}
			elsif ($what->{type} eq 'A') { # JS Array
				return [ map { _to_perl($_) } $what->arrayref->@* ];
			}
			elsif ($what->{type} eq 'O') { # JS Object
				# I think this only keeps alive methods defined directly as keys on this object? (TODO: test)
				my $hr = $what->hashref;
				return { map { ( $_ => _to_perl($hr->{$_}) ) } keys $hr->%* };
			}
			else { confess "internal error: unexpected type "._perlstr($what->{type}) }
		}
		else { return $what }
	}
	else { return $what }
}

sub js_new { js( 'new '.shift.'('.join(',',map {_to_js($_)} @_).')' ) }

{
	package WebPerl::JSObject;
	use Scalar::Util ();
	use overload
		'&{}' => \&coderef, '@{}' => \&arrayref, '%{}' => \&hashref,
		fallback => 0; #TODO Later: overload stringify? others?
	no overloading '%{}'; # so we can do $self->{...} without overloading
	
	# Note: constructor is WebPerl::js()
	
	sub jscode {
		my $self = shift;
		return 'Perl.GlueTable['.$WebPerl::JSON->encode($self->{id}).']';
	}
	
	sub AUTOLOAD {
		our $AUTOLOAD;
		#$TRACE and say STDERR "AUTOLOAD ",_perlstr($AUTOLOAD);
		( my $meth = $AUTOLOAD ) =~ s/^.*:://;
		splice @_, 1, 0, $meth;
		goto &methodcall;
	}
	sub methodcall {
		my $self = shift;
		my $meth = shift;
		return WebPerl::js($self->jscode
			.'['.$WebPerl::JSON->encode("$meth").']('.join(',',map {WebPerl::_to_js($_)} @_).')');
	}
	
	sub coderef {
		my $self = shift;
		if (!$self->{sub}) {
			my $gt = $self->jscode;
			$self->{sub} = sub {
				return WebPerl::js($gt.'('.join(',',map {WebPerl::_to_js($_)} @_).')');
			};
		}
		return $self->{sub};
	}
	
	sub arrayref {
		my $self = shift;
		my $array = $self->{array};
		if (!$array) {
			tie my @array, 'WebPerl::JSObject::TiedArray', $self;
			$array = $self->{array} = \@array;
			Scalar::Util::weaken($self->{array}); # tied obj holds a reference back to us, avoid circular references
		}
		return $array;
	}
	
	sub hashref {
		my $self = shift;
		my $hash = $self->{hash};
		if (!$hash) {
			tie my %hash, 'WebPerl::JSObject::TiedHash', $self;
			$hash = $self->{hash} = \%hash;
			Scalar::Util::weaken($self->{hash}); # tied obj holds a reference back to us, avoid circular references
		}
		return $hash;
	}
	
	sub toperl {
		my $self = shift;
		return WebPerl::_to_perl($self);
	}
	
	sub DESTROY {
		my $self = shift;
		#use Carp 'cluck'; cluck "DESTROY WebPerl::JSObject id $self->{id}"; # debug
		WebPerl::js('Perl.unglue('.$WebPerl::JSON->encode($self->{id}).')');
		return;
	}
}

{
	package # hide from pause
		WebPerl::JSObject::TiedArray;
	use parent 'Tie::Array';
	use Carp;
	sub TIEARRAY {
		confess "bad nr of args" unless @_==2;
		my $class = shift;
		my $obj = shift;
		return bless { obj=>$obj, gt=>$obj->jscode }, $class;
	}
	sub FETCH {
		my ($self,$idx) = @_;
		$idx=~/\A\d+\z/ or croak "bad array index '$idx'";
		return WebPerl::js($self->{gt}.'['.$idx.']');
	}
	sub STORE {
		my ($self,$idx,$val) = @_;
		$idx=~/\A\d+\z/ or croak "bad array index '$idx'";
		WebPerl::js($self->{gt}.'['.$idx.']='.WebPerl::_to_js($val));
		return;
	}
	sub FETCHSIZE {
		my ($self) = @_;
		return WebPerl::js($self->{gt}.'.length');
	}
	sub STORESIZE {
		my ($self,$count) = @_;
		$count=~/\A\d+\z/ or croak "bad array size '$count'";
		WebPerl::js($self->{gt}.'.length='.$count);
		return;
	}
	sub DELETE {
		my ($self,$idx) = @_;
		$idx=~/\A\d+\z/ or croak "bad array index '$idx'";
		carp "WARNING: Calling delete on array values is strongly discouraged."; # as per the "delete" docs
		WebPerl::js('delete '.$self->{gt}.'['.$idx.']');
		return;
	}
	sub EXISTS {
		my ($self,$idx) = @_;
		my $s = $self->FETCHSIZE;
		return $idx>=0 && $idx<$s;
	}
	sub EXTEND {} # not needed
	# provided by Tie::Array:  - TODO Later: we could implement some of these more efficiently ourselves
	#sub CLEAR {} # this
	#sub PUSH {} # this, LIST
	#sub POP {} # this
	#sub SHIFT {} # this
	#sub UNSHIFT {} # this, LIST
	#sub SPLICE {} # this, offset, length, LIST
	sub UNTIE {
		my $self = shift;
		$self->{obj} = undef;
		return;
	}
	sub DESTROY {}
}

{
	package # hide from pause
		WebPerl::JSObject::TiedHash;
	use Carp;
	sub TIEHASH {
		confess "bad nr of args" unless @_==2;
		my $class = shift;
		my $obj = shift;
		return bless { obj=>$obj, gt=>$obj->jscode }, $class;
	}
	sub FETCH {
		my ($self,$key) = @_;
		return WebPerl::js($self->{gt}.'['.$WebPerl::JSON->encode("$key").']');
	}
	sub STORE {
		my ($self,$key,$val) = @_;
		WebPerl::js($self->{gt}.'['.$WebPerl::JSON->encode("$key").'] = '.WebPerl::_to_js($val));
		return;
	}
	sub DELETE {
		my ($self,$key) = @_;
		WebPerl::js('delete '.$self->{gt}.'['.$WebPerl::JSON->encode("$key").']');
		return;
	}
	sub CLEAR {
		my ($self) = @_;
		WebPerl::js($self->{gt}.'={}'); #TODO Later: is replacing the whole object with a new one the right approach?
		return;
	}
	sub EXISTS {
		my ($self,$key) = @_;
		# alternatively: ('key' in obj), but that includes inherited stuff - what does the user expect here?
		return WebPerl::js($self->{gt}.'.hasOwnProperty('.$WebPerl::JSON->encode("$key").')');
	}
	sub FIRSTKEY {
		my ($self) = @_;
		$self->{keys} = [ map {"$_"} WebPerl::js( 'Object.keys('.$self->{gt}.')' )->@* ];
		$self->{key_idx} = 1;
		return $self->{keys}[0];
	}
	sub NEXTKEY {
		my ($self,$prevkey) = @_;
		return $self->{keys}[ $self->{key_idx}++ ];
	}
	sub SCALAR {
		my ($self) = @_;
		return WebPerl::js( 'Object.keys('.$self->{gt}.').length' );
	}
	sub UNTIE {
		my $self = shift;
		$self->{obj} = undef;
		return;
	}
	sub DESTROY {}
}

1;
