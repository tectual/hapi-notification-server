_      = require 'lodash'
Path   = require 'path'
fs     = require 'fs-extra'
moment = require 'moment'
Q      = require 'q'

module.exports = (server, options) -> 

  Message = require('../models/message')(options)
  Device = require('../models/device')(options)
  
  bucket = options.database

  privates =
    dir_ensure: (path) ->
      deferred = Q.defer()
      fs.ensureDir Path.dirname(path), (err) ->
        deferred.resolve(err)
      deferred.promise

    write_file: (file, data) ->
      deferred = Q.defer()
      fs.writeFile file, data, (error) ->
        deferred.resolve(error)
      deferred.promise

  {
    post: (request, reply) ->
      payload = request.payload
      unsubscribed_users =[]
      promises = []
      _.each payload.user_keys, (user_key) ->
        promises.push(
          Device.check_if_user_unsubscribed(user_key, payload.template)
            .then (unsubscribed) ->
              unsubscribed_users.push(user_key) if unsubscribed
        )
      Q.all(promises).then( () ->
        user_keys = _.difference(payload.user_keys, unsubscribed_users)
        message = new Message
        message.load(request.payload.template).then( (template) ->
          if options.config.mock
            if options.config.trace
              console.log message.render payload.data, 'android'
              console.log message.render payload.data, 'iphone'
            if options.config.dump
              file = Path.join options.config.dump_path, "#{payload.template}_#{user_keys.join(',')}.json"
              privates.dir_ensure(file)
              .then (err) ->
                return reply.badImplementation "something's wrong with dump path" if err
                data =
                  android: JSON.parse(message.render(payload.data, 'android'))
                  iphone: JSON.parse(message.render(payload.data, 'iphone'))
                privates.write_file(file, JSON.stringify(data) )
              .then (error) ->
                return reply.badImplementation "something's went wrong when writing to dump path" if error
                console.log "dumped to: #{file}"
                reply.success true
            else
              reply.success true
          else
            _.each user_keys, (u) ->
              Device.find_by_user(u).then (device) ->
                message.deliver( device, payload.data )
            reply.success true
        )
      ).done()

    get_notification_levels: (request, reply) ->
      notification_levels = _.keys(options.config.notification_levels)
      reply.nice notification_levels
  }
