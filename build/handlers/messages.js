(function() {
  var Path, Q, _, fs, moment;

  _ = require('lodash');

  Path = require('path');

  fs = require('fs-extra');

  moment = require('moment');

  Q = require('q');

  module.exports = function(server, options) {
    var Device, Message, bucket, privates;
    Message = require('../models/message')(options);
    Device = require('../models/device')(options);
    bucket = options.database;
    privates = {
      dir_ensure: function(path) {
        var deferred;
        deferred = Q.defer();
        fs.ensureDir(Path.dirname(path), function(err) {
          return deferred.resolve(err);
        });
        return deferred.promise;
      },
      write_file: function(file, data) {
        var deferred;
        deferred = Q.defer();
        fs.writeFile(file, data, function(error) {
          return deferred.resolve(error);
        });
        return deferred.promise;
      }
    };
    return {
      post: function(request, reply) {
        var message, payload;
        payload = request.payload;
        message = new Message;
        return message.load(request.payload.template).then(function(template) {
          var file;
          if (options.config.mock) {
            if (options.config.trace) {
              console.log(message.render(payload.data, 'android'));
              console.log(message.render(payload.data, 'iphone'));
            }
            if (options.config.dump) {
              file = Path.join(options.config.dump_path, payload.template + "_" + (moment().unix()) + ".json");
              return privates.dir_ensure(file).then(function(err) {
                var data;
                if (err) {
                  return reply.badImplementation("something's wrong with dump path");
                }
                data = {
                  android: JSON.parse(message.render(payload.data, 'android')),
                  iphone: JSON.parse(message.render(payload.data, 'iphone'))
                };
                return privates.write_file(file, JSON.stringify(data));
              }).then(function(error) {
                if (error) {
                  return reply.badImplementation("something's went wrong when writing to dump path");
                }
                console.log("dumped to: " + file);
                return reply.success(true);
              });
            } else {
              return reply.success(true);
            }
          } else {
            _.each(payload.user_keys, function(u) {
              return Device.find_by_user(u).then(function(device) {
                return message.deliver(device, payload.data);
              });
            });
            return reply.success(true);
          }
        }).done();
      }
    };
  };

}).call(this);
