# Description:
#   hubot-mongodb-brain
#   support MongoLab and MongoHQ on heroku.
#
# Dependencies:
#   "mongodb": "*"
#   "lodash" : "*"
#
# Configuration:
#   MONGODB_URL or MONGOLAB_URI or MONGOHQ_URL or 'mongodb://localhost/hubot-brain'
#
# Author:
#   Sho Hashimoto <hashimoto@shokai.org>

'use strict'

_           = require 'lodash'
MongoClient = require('mongodb').MongoClient

deepClone = (obj) -> JSON.parse JSON.stringify obj

module.exports = (robot) ->
  mongoUrl = process.env.MONGODB_URL or
             process.env.MONGOLAB_URI or
             process.env.MONGOHQ_URL or
             'mongodb://localhost/hubot-brain'

  MongoClient.connect mongoUrl, (err, db) ->
    throw err if err

    robot.brain.on 'close', ->
      db.close()

    robot.logger.info "MongoDB connected"
    robot.brain.setAutoSave false

    cache = {}
    ucache = {}

    ## restore data from mongodb
    db.createCollection 'brain', (err, collection) ->
      collection.find({type: '_private'}).toArray (err, docs) ->
        return robot.logger.error err if err
        _private = {}
        for doc in docs
          _private[doc.key] = doc.value
        cache = deepClone _private
        robot.brain.mergeData {_private: _private}
    db.createCollection 'users', (err, collection) ->
      collection.find({type: 'users'}).toArray (err, docs) ->
        return robot.logger.error err if err
        users = {}
        for doc in docs
          users[doc.key] = doc.value
        ucache = deepClone users
        robot.brain.mergeData {users: users}
    robot.brain.resetSaveInterval 10
    robot.brain.setAutoSave true

    ## save data into mongodb
    robot.brain.on 'save', (data) ->
      db.collection 'brain', (err, collection) ->
        for k,v of data._private
          do (k,v) ->
            return if _.isEqual cache[k], v  # skip not modified key
            robot.logger.debug "save \"#{k}\" into mongodb-brain"
            cache[k] = deepClone v
            collection.update
              type: '_private'
              key:  k
            ,
              $set:
                value: v
            ,
              upsert: true
            , (err, res) ->
              robot.logger.error err if err
            return

      db.collection 'users', (err, collection) ->
        for k,v of data.users
          do (k,v) ->
            return if _.isEqual ucache[k], v  # skip not modified key
            robot.logger.debug "save \"#{k}\" into mongodb-brain"
            ucache[k] = deepClone v
            collection.update
              type: 'users'
              key:  k
            ,
              $set:
                value: v
            ,
              upsert: true
            , (err, res) ->
              robot.logger.error err if err
            return

