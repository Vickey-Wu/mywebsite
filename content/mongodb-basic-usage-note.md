---
title: "mongodb基本用法"
date: 2019-06-19T03:10:06Z
description: "This is meta description"
type: "post"
image: "https://s1.ax1x.com/2020/04/16/JFEZUf.md.jpg"
categories:
  - "mongodb"
tags:
  - "mongodb"
---

#### introduction

> this note include mongodb installation, basic usage, user authority

#### installation

>reference: https://docs.mongodb.com/manual/tutorial/install-mongodb-on-ubuntu/

- 1.add key

```
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 9DA31620334BD75D9DCB49F368818C72E52529D4
```

- add to sources.list (Ubuntu 16.04 (Xenial))

```
echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu xenial/mongodb-org/4.0 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.0.list
```

- 2.install

```
sudo apt-get update
sudo apt-get install -y mongodb-org
```

- 3.run backgroud

>default port: 27017, path: /var/lib/mongodb, can be self-define

```
/usr/bin/mongod -f /etc/mongod.conf &
```
or
```
mongod --port 27017 --dbpath /data/db
```

- 4.mongod.conf

>if wanna access db through public ip set `bindIp: 0.0.0.0` or specified an ip

```
root@ubuntu:/etc# cat mongod.conf 
# mongod.conf

# for documentation of all options, see:
#   http://docs.mongodb.org/manual/reference/configuration-options/

# Where and how to store data.
storage:
  dbPath: /var/lib/mongodb
  journal:
    enabled: true
#  engine:
#  mmapv1:
#  wiredTiger:

# where to write logging data.
systemLog:
  destination: file
  logAppend: true
  path: /var/log/mongodb/mongod.log

# network interfaces
net:
  port: 27017
  bindIp: 0.0.0.0
  #bindIp: 127.0.0.1

# how the process runs
processManagement:
  timeZoneInfo: /usr/share/zoneinfo
```
#### basic usage
- 1.windows install(ignore)

>reference: https://docs.mongodb.com/manual/tutorial/install-mongodb-on-windows/

![](https://note.youdao.com/yws/api/personal/file/6EB81BD475F3414B9ED339CF6709E509?method=download&shareKey=bd1b802903bc91c2659e14133ff9ec65)

- 2.start

>almost all operation has `one`(`db.insertOne()`) and `many`(`db.insertMany()`) function, i only record `one` operation

```
/usr/bin/mongo
# or 
mongo
```

- 3.use db(create operation)

>reference: https://docs.mongodb.com/manual/reference/mongo-shell/

>mongodb default `dbs` "admin", "config", "local", no `collections`(table), no `documents`(table's record)

```
> show dbs
admin            0.000GB
config           0.000GB
local            0.000GB
> show databases
admin            0.000GB
config           0.000GB
local            0.000GB
> show tables       # output nothing because of no table
> show collections  # output nothing because of no collections
>
```

>use `db` show the db using now, use dbname to switch to db existed or use self defined dbname to create db, we can use self defedined db and table, such as `self_defined_db` and `self_defined_db`'s table `first_table`

```
> db
test
> use test
switched to db test
> use self_defined_db
switched to db self_defined_db
> db.first_table.insertOne({name: "vickey", age: 18})
{
	"acknowledged" : true,
	"insertedId" : ObjectId("5d0226daaea0917927c50511")
}
> db.first_table.insertOne({name: "vickey1", age: 19, sex: "male"})
{
	"acknowledged" : true,
	"insertedId" : ObjectId("5d02fb87f227aaf10b436012")
}
> show collections
first_table
```

- 4.query operation
>as we can see, we can use `db.tablename.find({key: value})` to find record in table exsited, but can't find record in table not exsited, such as `second_table`(output nothing), we should create them firstly. we can find all `documents`(records) by `db.tablename.find().pretty()`
```
> db.first_table.find({name: "vickey"})
{ "_id" : ObjectId("5d0226daaea0917927c50511"), "name" : "vickey", "age" : 18 }
> db.first_table.find({name: "vicke"})
> db.second_table.find({name: "vickey"})
> 
> db.first_table.find().pretty()
{
	"_id" : ObjectId("5d02fb66f227aaf10b436011"),
	"name" : "vickey",
	"age" : 18
}
{
	"_id" : ObjectId("5d02fb87f227aaf10b436012"),
	"name" : "vickey1",
	"age" : 19,
	"sex" : "male"
}
```

- 5.update operation

>I update the record's name, output `"modifiedCount": non-zero` if successed, then we only find the record with new name
```
> db.first_table.updateOne({name: "vickey"}, {$set: {name: "vickey wu"}})
{ "acknowledged" : true, "matchedCount" : 1, "modifiedCount" : 1 }
> db.first_table.find({name: "vickey"})
> db.first_table.find({name: "vickey*"})
> db.first_table.find({name: "vickey wu"})
{ "_id" : ObjectId("5d0226daaea0917927c50511"), "name" : "vickey wu", "age" : 18 }
```

- 6.replace operation
>different with update operation, replace operation would `replace all keys in the record` by the one you replace. from the follow example we can see that the record key `age` also be replaced with nothing, in other word, be deleted, because we didn't replace key `age` with an actual value

``` 
> db.first_table.replaceOne({name: "vickey wu"}, {name: "vickey"})
{ "acknowledged" : true, "matchedCount" : 1, "modifiedCount" : 1 }
> db.first_table.find({name: "vickey"})
{ "_id" : ObjectId("5d0226daaea0917927c50511"), "name" : "vickey" }      # key 'age' was deleted
```

>if every key in the record were given, then would no key was deleted

``` 
> db.first_table.replaceOne({name: "vickey"}, {name: "vickey", age: 18})
{ "acknowledged" : true, "matchedCount" : 1, "modifiedCount" : 1 }
> db.first_table.find({name: "vickey"})
{ "_id" : ObjectId("5d0226daaea0917927c50511"), "name" : "vickey", "age" : 18 }
```

- 7.delete operation

>delete document(delete one document that `name` is `vickey1` that we add at create operation)

```
> show dbs
admin            0.000GB
config           0.000GB
local            0.000GB
self_defined_db  0.000GB
>use self_defined_db
switched to db self_defined_db
>show collections
first_table
> db.first_table.deleteOne({name: "vickey1"})
{ "acknowledged" : true, "deletedCount" : 1 }
> db.first_table.find().pretty()
{
	"_id" : ObjectId("5d02fb66f227aaf10b436011"),
	"name" : "vickey",
	"age" : 18
}
```

>delete collection

```
>use self_defined_db
switched to db self_defined_db
>show collections
first_table
> db.first_table.drop()
true
> show collections      # output nothing because we had deleted the only table in collection
>
```

>delete db(first use `use dbname` to switch to target db, then use delete command)

```
> show dbs
admin            0.000GB
config           0.000GB
local            0.000GB
self_defined_db  0.000GB
> use self_defined_db
switched to db self_defined_db
> db.dropDatabase()
{ "dropped" : "self_defined_db", "ok" : 1 }
> show dbs
admin            0.000GB
config           0.000GB
local            0.000GB
```

- 8.advanced usage

>more advanced usage see official docs: https://docs.mongodb.com/manual/crud/

#### user security

>createuser reference: https://docs.mongodb.com/manual/reference/method/db.createUser/#examples

>to run mongodb security(need to auth user firstly) we should use follow command to run or restart mongod

```
mongod --auth --fork -f /etc/mongod.conf
```
>mongodb does not enable access control by default, we can create a user by `db.createUser()`, e.g:crate a empty roles for user vickey

```
> use self_defined_db
switched to db self_defined_db
>db.createUser({user: "vickey", pwd: "password", roles: [ "readWrite", "dbAdmin" ]})
```

> try to restart mongo to test auth after set roles for user

```
> show dbs      # output nothing because we didn't use db.auth() to auth user
> use self_defined_db
switched to db self_defined_db
> show collections
Warning: unable to run listCollections, attempting to approximate collection names by parsing connectionStatus
> db.auth("vickey", "password")
1
> show collections
test_table
> show dbs      # output dbs after auth user
test  0.000GB
```
