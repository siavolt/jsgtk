#!/usr/bin/env gjs

/* jshint esversion: 6, strict: true, node: true */
/* global imports */

(function (runtime) {'use strict';

  /*! MIT Style License

    Copyright (c) 2015 - 2016   Andrea Giammarchi @WebReflection

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
    THE SOFTWARE.

  */

  const

    // basic dependencies
    gi = imports.gi,
    GLib = gi.GLib,
    GFile = gi.Gio.File,

    // scoped global + shortcuts
    global = window,
    replace = String.prototype.replace,

    // folders bootstrap
    CURRENT_DIR = GLib.get_current_dir(),
    DIR_SEPARATOR = /\//.test(CURRENT_DIR) ? '/' : '\\',
    PROGRAM_NAME = imports.system.programInvocationName,
    PROGRAM_DIR = ((exe) => {
      let
        dir = exe.slice(0, -(1 + GLib.path_get_basename(exe).length)),
        path = dir.split(DIR_SEPARATOR)
      ;
      switch (path[path.length - 1]) {
        // global case
        case 'bin':
          path.pop();
          path.push('lib', 'jsgtk');
          dir = path.join(DIR_SEPARATOR);
          break;
        // local module
        case '.bin':
          path.pop();
          path.push('jsgtk');
          dir = path.join(DIR_SEPARATOR);
          break;
      }
      return dir;
    })(GFile.new_for_path(PROGRAM_NAME).get_path())
  ;

  // inject the jsgtk folder to import at runtime internal helpers
  imports.searchPath.push([PROGRAM_DIR, 'jsgtk_modules'].join(DIR_SEPARATOR));

  // populate the constants file
  Object.defineProperties(
    imports.jsgtk.constants,
    {
      CURRENT_DIR: {enumerable: true, value: CURRENT_DIR},
      DEBUG: {enumerable: true, value: ARGV.some(arg => arg === '--debug')},
      DIR_SEPARATOR: {enumerable: true, value: DIR_SEPARATOR},
      PROGRAM_NAME: {enumerable: true, value: PROGRAM_NAME},
      PROGRAM_DIR: {enumerable: true, value: PROGRAM_DIR}
    }
  );

  // bring in polyfills and all modules loaders + process and timers
  const
    polyfills = imports.jsgtk.polyfills,
    mainloop = imports.jsgtk.mainloop,
    gtk = imports.jsgtk.gtk_modules.withRuntime(evaluateModule),
    core = imports.jsgtk.core_modules.withRuntime(evaluateModule),
    modules = imports.jsgtk.node_modules.withRuntime(evaluateModule),
    process = core.get('process'),
    timers =  core.get('timers')
  ;

  // env normalization
  Object.defineProperties(
    Object.defineProperty(
      global,
      'process',
      {enumerable: true, value: process}
    ),
    {
      global: {enumerable: true, value: global},
      console: {enumerable: true, value: core.get('console')},
      clearInterval: {enumerable: true, value: timers.clearInterval},
      clearTimeout: {enumerable: true, value: timers.clearTimeout},
      setInterval: {enumerable: true, value: timers.setInterval},
      setTimeout: {enumerable: true, value: timers.setTimeout}
    }
  );

  // module handler
  function evaluateModule(nmsp, unique, id, fd, transform) {
    const
      dir = id.slice(0, -1 -fd.get_basename().length),
      exports = {},
      module = {exports: exports, id: id}
    ;
    nmsp[unique] = exports;
    runtime(
      'require',
      'exports',
      'module',
      '__dirname',
      '__filename',
      (transform || String)(
        replace.call(fd.load_contents(null)[1], /^#![^\n\r]*/, '')
      )
    ).call(
      exports,
      function require(module) {
        return requireWithPath(module, dir);
      },
      exports,
      module,
      dir,
      id
    );
    return (nmsp[unique] = module.exports);
  }

  // the actual require
  function requireWithPath(module, dir) {
    switch (true) {
      case core.has(module):
        return core.get(module);
      case gtk.has(module):
        return gtk.get(module);
      default:
        return modules.get(module) || modules.load(module, dir);
    }
  }

  // program bootstrap
  if (process.argv.length > 1) {
    requireWithPath(process.argv[1], CURRENT_DIR);
    mainloop.run();
  } else {
    if (ARGV.some((info, i) => {
      if (i && /^-e|--eval$/.test(ARGV[i - 1])) {
        runtime(
          'require',
          '__dirname',
          '__filename',
          info
        ).call(
          global,
          function require(module) {
            return requireWithPath(module, CURRENT_DIR);
          },
          CURRENT_DIR,
          '[eval]'
        );
        return true;
      }
      return false;
    })) {
      mainloop.run();
    } else {
      print([
        'Usage: jsgtk [options] script.js [arguments]',
        '       jsgtk --debug script.js [arguments]',
        '       jsgtk (-e|--eval) "console.log(\'runtime\')"',
        '',
        'Documentation can be found at https://github.com/WebReflection/jsgtk'
      ].join('\n'));
    }
  }

}(Function));