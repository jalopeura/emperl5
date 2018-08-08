'use strict';

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

const nodepath = require('path');
var Module = {
	preRun: [
		function() {
			var mounts = [ { virtual:__dirname, real:__dirname } ];
			if (process.env.EMPERL_PREFIX && process.env.EMPERL_OUTPUTDIR)
				mounts.push( { virtual:process.env.EMPERL_PREFIX,
					real:nodepath.join(process.env.EMPERL_OUTPUTDIR,process.env.EMPERL_PREFIX) } );
			for (var i = 0; i < mounts.length; i++) {
				var paths = mounts[i].virtual.split(nodepath.sep);
				var newpath = nodepath.parse(mounts[i].virtual).root;
				for (var j = 1; j < paths.length; j++) {
					newpath = nodepath.join(newpath, paths[j]);
					try { FS.mkdir(newpath); } catch(e) {}
				}
				FS.mount(NODEFS,
					{ root: mounts[i].real },
					mounts[i].virtual );
			}
			try { FS.chdir( process.cwd() ); } catch(e) {}
		},
		function() {
			// patch _main so that afterwards we call emperl_end_perl
			var origMain = Module._main;
			Module._main = function() {
				origMain.apply(this, arguments);
				return ccall("emperl_end_perl","number",[],[]);
			};
		}
	],
	locateFile: function (file) {
		var wasmRe = /(\.wast|\.wasm|\.asm\.js)$/;
		if (wasmRe.exec(file)) {
			return nodepath.join(__dirname,file);
		}
		return file;
	},
	thisProgram: nodepath.join(__dirname,"perl") /* so Perl's $^X is correct */
};
