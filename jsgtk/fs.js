(function (exports) {'use strict';

  const
    Gio = imports.gi.Gio,
    ByteArray = imports.byteArray
  ;

  exports.readFile = function readFile(file, options, callback) {
    // TODO: supports options
    if (!callback) callback = options;
    Gio.File.new_for_path(file)
      .load_contents_async(null, (source, result) => {
        try {
          let [ok, data, etag] = source.load_contents_finish(result);
          if (!ok) throw 'Unable to read ' + file;
          callback(null, data.toString());
        } catch(err) {
          callback(err);
        }
      });
  }

  exports.readFileSync = function readFileSync(file, options) {
    // TODO: supports options
    return Gio.File.new_for_path(file).load_contents(null)[1].toString();
  };

  exports.writeFileSync = function writeFileSync(file, data, options) {
    // TODO: supports options
    let fd, stream, result;
    options = getWriteOptions(options);
    switch (options.flag) {
      case 'w':
        fd = Gio.File.new_for_path(file);
        try {
          stream = fd.create_readwrite(Gio.FileCreateFlags.REPLACE_DESTINATION, null).output_stream;
        } catch(e) {
          stream = fd.open_readwrite(null).output_stream;
        }
        stream.truncate(0, null);
        stream.write_all(String(data), null);
        stream.flush(null);
        result = stream.close(null);
    }
    return result;
  };

  exports.writeFile = function writeFileSync(file, data, options, callback) {
    // TODO: supports options
    let fd;
    if (typeof options === 'function') {
      callback = options;
      options = getWriteOptions(null);
    } else {
      options = getWriteOptions(options);
    }
    switch (options.flag) {
      case 'w':
        let onceFoundAWayTowrite = (stream) => {
          stream.truncate(0, null);
          stream.output_stream.write_bytes_async(
            ByteArray.fromString(String(data)),
            0,
            null,
            (source, result) => {
              source.write_bytes_finish(result);
              source.flush_async(0, null, (source, result) => {
                source.flush_finish(result);
                source.close_async(0, null, (source, result) => {
                  callback(!source.close_finish(result));
                });
              });
            }
          );
        };
        fd = Gio.File.new_for_path(file);
        fd.create_readwrite_async(
          Gio.FileCreateFlags.REPLACE_DESTINATION,
          0,
          null,
          (source, result) => {
            try {
              onceFoundAWayTowrite(source.create_readwrite_finish(result));
            } catch(e) {
              fd.open_readwrite_async(
                0,
                null,
                (source, result) => {
                  onceFoundAWayTowrite(source.open_readwrite_finish(result));
                }
              );
            }
          }
        );
        break;
    }
  };

  function getWriteOptions(options) {
    if (!options) options = {};
    if (!options.encoding) options.encoding = 'utf8';
    if (!options.mode) options.mode = 666;
    if (!options.flag) options.flag = 'w';
    return options;
  }

}(this));