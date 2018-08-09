use warnings;
use 5.028;
use Test::More;

=head1 SYNOPSIS

Tests for F<WebPerl.pm>, to be run in the browser.

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

# A couple of debugging aides:
#$WebPerl::TRACE = 1;
#js('Perl.trace = true');
#$Carp::Verbose = 1; # or:
#use Devel::StackTrace ();
#$SIG{__DIE__} = sub { die join '', shift, map {"\t".$_->as_string."\n"}
#		Devel::StackTrace->new(skip_frames=>2)->frames };

BEGIN { use_ok('WebPerl', qw/ js encode_json sub1 /) }

subtest 'basic js() tests' => sub {
	is js(undef), undef, 'undef';
	is js(q{ undefined }), undef, 'undefined';
	is js(q{ true }), !0, 'true';
	is js(q{ false }), !1, 'false';
	is js(q{ 5 }), 5, 'number 1';
	is js(q{ 3.14159 }), 3.14159, 'number 2';
	is js(q{ 3.14159e6 }), 3.14159e6, 'number 3';
	is js(q{ 3.14159e60 }), 3.14159e60, 'number 4';
	is js(q{ "" }), "", 'string 1';
	is js(q{ "foo" }), "foo", 'string 2';
	is js(qq{"\0\\0\N{U+E4}\\u00E4"}), "\0\0\N{U+E4}\N{U+E4}", 'nuls and unicode'; #"
};

subtest 'basic function tests' => sub {
	my $func = js(q{ (function (x,y) { return "x"+x+"y"+y+"z" }) });
	isa_ok $func, 'WebPerl::JSObject';
	is $func->("a","b"), "xaybz", 'func call';
	is js('(function (d) {return d})')->("\0\N{U+E4}\x{2665}"),
		"\0\N{U+E4}\x{2665}", 'unicode passed as arg & rv';
	
	my $pl = $func->toperl;
	is ref $pl, 'CODE', 'toperl gives code ref';
	is $pl->('i','j'), 'xiyjz', 'code ref works';
	
	is js( '('.js([qw/foo bar quz/])->jscode.')[1]' ), "bar", 'basic jscode test';
	ok js( '('.js('document')->jscode.')===('.js('document')->jscode.')' ), 'jscode equality test';
	ok !js( '('.js('document')->jscode.')===('.js('window')->jscode.')' ), 'jscode inequality test';
};

subtest 'basic array test' => sub {
	my $arr = js(q{ testarray = [3,1,4,1,5,9]; (testarray) });
	isa_ok $arr, 'WebPerl::JSObject';
	is_deeply [@$arr], [3,1,4,1,5,9], 'array values';
	$arr->[4] = 'x';
	is js('testarray[4]'), 'x', 'setting successful';
	
	my $ref = $arr->arrayref;
	is_deeply $ref, [3,1,4,1,'x',9], 'arrayref values';
	is ref $ref, 'ARRAY', 'arrayref gives arrayref';
	isa_ok tied(@$ref), 'WebPerl::JSObject::TiedArray';
	$ref->[5] = 'y';
	is js('testarray[5]'), 'y', 'setting successful 2';
	
	my $plain = $arr->toperl;
	is_deeply $plain, [3,1,4,1,'x','y'], 'toperl values';
	is ref $plain, 'ARRAY', 'toperl gives arrayref';
	ok !tied(@$plain), 'toperl result isn\'t tied';
};

subtest 'basic object test' => sub {
	my $obj = js(q{ ({ hello: "world!", foo : function () { return "foobar!" } }) });
	isa_ok $obj, 'WebPerl::JSObject';
	is_deeply [sort keys %$obj], ['foo','hello'], 'keys on object';
	is $obj->{hello}, "world!", 'simple object value';
	isa_ok $obj->{foo}, 'WebPerl::JSObject';
	is $obj->foo, 'foobar!', 'method call';
};

subtest 'encode_json' => sub {
	my $json = encode_json( { Hello=>"World!" } );
	my $jo = js( "($json)" );
	isa_ok $jo, 'WebPerl::JSObject', 'json';
	is $jo->{Hello}, 'World!', 'json object key/value';
};

subtest 'advanced function tests' => sub {
	js(' (function (cb) { cb("yup") }) ')
		->( sub1 {
			is shift, "yup", "calling between JS<->Perl";
		} );
	my $passthru =
		js(q{ (function (cb) { var rv = cb({hello:"world"}); return rv } ) })
		->(sub { return shift });
	isa_ok $passthru, 'WebPerl::JSObject', 'passthru worked 1';
	is $passthru->{hello}, 'world', 'passthru worked 2';
};

done_testing;

note "All tests passed!" if Test::More->builder->is_passing;

