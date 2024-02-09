#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

/** ***** WebPerl - http://webperl.zero-g.net *****
 * 
 * Copyright (c) 2018 Hauke Daempfling (haukex@zero-g.net)
 * at the Leibniz Institute of Freshwater Ecology and Inland Fisheries (IGB),
 * Berlin, Germany, http://www.igb-berlin.de
 * 
 * This program is free software; you can redistribute it and/or modify
 * it under the same terms as Perl 5 itself: either the GNU General Public
 * License as published by the Free Software Foundation (either version 1,
 * or, at your option, any later version), or the "Artistic License" which
 * comes with Perl 5.
 * 
 * This program is distributed in the hope that it will be useful, but
 * WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 * See the licenses for details.
 * 
 * You should have received a copy of the licenses along with this program.
 * If not, see http://perldoc.perl.org/index-licence.html
**/

#include <emscripten.h>

SV* json_object;

extern int emperl_end_perl();

SV* webperl_perlify(pTHX_ const char* in) {
	if (in == NULL) {
		return NULL;
	}

	dSP;
	dTARGET;
	ENTER;
	SAVETMPS;

	PUSHMARK(SP);
	EXTEND(SP, 2);
	PUSHs(json_object);
	PUSHp(in, strlen(in));
	PUTBACK;

	I32 count = call_pv("Cpanel::JSON::XS::decode", G_SCALAR);

	SPAGAIN;

	if (count != 1) {
		croak("Unable to jsonify result");
	}

	SV* out = POPs;

	// increment the refcount so it will survive FREETMPS
	SvREFCNT_inc(out);

	PUTBACK;
	FREETMPS;
	LEAVE;

	// mortalize it so it doesn't hang around
	sv_2mortal(out);

	// this is left mortal, so caller needs to use it quick or increment the refcount
	return out;
}

const char* webperl_jsonify(pTHX_ SV* in) {
	dSP;
	ENTER;
	SAVETMPS;

	PUSHMARK(SP);
	EXTEND(SP, 2);
	PUSHs(json_object);
	PUSHs(in);
	PUTBACK;

	I32 count = call_pv("Cpanel::JSON::XS::encode", G_SCALAR);

	SPAGAIN;

	if (count != 1) {
		croak("Unable to jsonify result");
	}

	SV* out = POPs;

	// increment the refcount so it will survive FREETMPS
	SvREFCNT_inc(out);

	PUTBACK;
	FREETMPS;
	LEAVE;

	// mortalize it so it doesn't hang around
	sv_2mortal(out);

	return SvPV_nolen(out);
}

// a simple wrapper for eval_pv
const char* webperl_eval_perl(pTHX_ const char* code) {
	SV *rv = eval_pv(code, TRUE);
	return webperl_jsonify(aTHX_ rv);
}

// a wrapper for call_pv
const char* webperl_call_perl(pTHX_ const char* sub_name, const char* json_args, I32 flags) {
	dSP;
	ENTER;
	SAVETMPS;

	PUSHMARK(SP);
	SV* aref_args = NULL;
	if (json_args) {
		aref_args = webperl_perlify(json_args);
		if (SvROK(aref_args)) {
			AV* array = (AV*)SvRV(aref_args);
			int count = av_count(array);
			if (count > 0) {
				SV** item;
				EXTEND(SP, count);
				for (int i = 0; i < count; i++) {
					item = av_fetch(array, i, 1);
					if (item != NULL) {
						PUSHs(*item);
					}
				}
			}
		}
	}
	PUTBACK;

	I32 count = call_pv(sub_name, flags);

	SPAGAIN;

	SV* rv;
	if (count) {
		if ((flags & G_WANT) == G_LIST) {
			AV* array = newAV();
			for (int i = 0; i < count; i++) {
				SV* item = POPs;
				SvREFCNT_inc(item);
				av_unshift(array, 1);
				av_store(array, 0, item);
			}
			rv = newRV_noinc((SV*)array);
		}
		else {
			rv = POPs;
			SvREFCNT_inc(rv);
		}
	}
	else {
		rv = &PL_sv_undef;
	}

	PUTBACK;
	FREETMPS;
	LEAVE;

	// mortalize it so it doesn't hang around
	sv_2mortal(rv);

	return webperl_jsonify(aTHX_ rv);
}

int webperl_pointer_size() {
	return Size_t_size;
}

// STRLEN=MEM_SIZE=Size_t, and the code below (accessing HEAP32) currently assumes this is 4 bytes
#if Size_t_size!=4
#error "Unsupported Size_t"
#endif

EM_JS(const char*, js_eval_js, (const char* codestr, STRLEN ilen, int wantrv, STRLEN* olen), {
	var out = "";
	try {
		var code = my_UTF8ArrayToString(codestr, ilen);
		if (Perl.trace) console.debug("Perl: eval", code, "- wantrv",wantrv);
		var rv = eval(code);
		if (wantrv==0)       // js() was called in void context, so we don't need
			rv = undefined;  // any handling of the return value, especially GlueTable stuff!
		// In the future, we could switch to using the supposedly faster Function constructor,
		// but we need to make sure callers know this because of the differences (e.g. in accessing global JS objects)
		//var rv = Function( '"use strict"; return (' + code + ')' )();
		switch (typeof rv) {
			case "undefined":
				out = "U";
				break;
			case "boolean":
				out = (rv ? "1" : "0") + "B";
				break;
			case "number":
				out = String(rv) + "N";
				break;
			case "string":
				out = rv + "S";
				break;
			case "function":
				out = Perl.glue(rv) + "F";
				break;
			case "object":
				if (rv==null)
					out = "U";
				else if (Array.isArray(rv))
					out = Perl.glue(rv) + "A";
				else
					out = Perl.glue(rv) + "O";
				break;
			default:
				console.warn("js_get_js: unsupported return type",rv);
				out = (typeof rv) + "X";
				break;
		}
	}
	catch (ex) {
		out = ex + "E";
	}
	if (Perl.trace) console.debug("Perl: returning", out);
	var lengthBytes = lengthBytesUTF8(out); // without null terminator
	HEAP32[olen>>2] = lengthBytes;
	var stringOnWasmHeap = _malloc(lengthBytes+1); // plus null terminator
	stringToUTF8(out, stringOnWasmHeap, lengthBytes+1); // not yet sure why +1 is needed here
	return stringOnWasmHeap;
});

MODULE = WebPerl		PACKAGE = WebPerl
PROTOTYPES: DISABLE

int
refcount(ref)
	SV *ref
	CODE:
		RETVAL = SvROK(ref) ? SvREFCNT(SvRV(ref)) : -1;
	OUTPUT:
		RETVAL

SV *
xs_eval_js(code, wantrv)
	SV*	code
	int	wantrv
	INIT:
		STRLEN ilen;
		STRLEN olen;
		char *codestr;
		const char *out;
	CODE:
		codestr = SvPV(code, ilen);
		out = js_eval_js(codestr, ilen, wantrv, &olen);
		RETVAL = newSVpvn_utf8(out, olen, 1);
		free((void*)out);
	OUTPUT:
		RETVAL

int
end_perl()
	CODE:
		// TODO Later: end_perl() doesn't cause Module.onExit to be called, right?
		RETVAL = emperl_end_perl();
	OUTPUT:
		RETVAL

BOOT:
	json_object = get_sv("WebPerl::JSON", GV_ADD);