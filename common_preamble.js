"use strict";

// A version of emscripten's UTF8ArrayToString that uses a length argument and doesn't need a null byte
var my_UTF8Decoder = typeof TextDecoder !== 'undefined' ? new TextDecoder('utf8') : undefined;
function my_UTF8ArrayToString(ptr, len) {
	var endPtr = ptr + len;
	if (len > 16 && HEAPU8.subarray && my_UTF8Decoder) {
		return my_UTF8Decoder.decode(HEAPU8.subarray(ptr, endPtr));
	} else {
		var u0, u1, u2, u3, u4, u5;
		var str = '';
		while (ptr<endPtr) {
			u0 = HEAPU8[ptr++];
			if (!(u0 & 0x80)) { str += String.fromCharCode(u0); continue; }
			u1 = HEAPU8[ptr++] & 63;
			if ((u0 & 0xE0) == 0xC0) { str += String.fromCharCode(((u0 & 31) << 6) | u1); continue; }
			u2 = HEAPU8[ptr++] & 63;
			if ((u0 & 0xF0) == 0xE0) {
				u0 = ((u0 & 15) << 12) | (u1 << 6) | u2;
			} else {
				u3 = HEAPU8[ptr++] & 63;
				if ((u0 & 0xF8) == 0xF0) {
					u0 = ((u0 & 7) << 18) | (u1 << 12) | (u2 << 6) | u3;
				} else {
					u4 = HEAPU8[ptr++] & 63;
					if ((u0 & 0xFC) == 0xF8) {
						u0 = ((u0 & 3) << 24) | (u1 << 18) | (u2 << 12) | (u3 << 6) | u4;
					} else {
						u5 = HEAPU8[ptr++] & 63;
						u0 = ((u0 & 1) << 30) | (u1 << 24) | (u2 << 18) | (u3 << 12) | (u4 << 6) | u5;
					}
				}
			}
			if (u0 < 0x10000) {
				str += String.fromCharCode(u0);
			} else {
				var ch = u0 - 0x10000;
				str += String.fromCharCode(0xD800 | (ch >> 10), 0xDC00 | (ch & 0x3FF));
			}
		}
		return str;
	}
}

