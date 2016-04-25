xquery version "3.0";

import module namespace xdb="http://exist-db.org/xquery/xmldb";

import module namespace config = "@app.uri@/config" at "modules/config.xqm";

(: The following external variables are set by the repo:deploy function :)

(: file path pointing to the exist installation directory :)
declare variable $home external;
(: path to the directory containing the unpacked .xar package :)
declare variable $dir external;
(: the target collection into which the app is deployed :)
declare variable $target external;

declare function local:mkcol-recursive($collection, $components) {
    if (exists($components)) then
        let $newColl := concat($collection, "/", $components[1])
        return (
            xdb:create-collection($collection, $components[1]),
            local:mkcol-recursive($newColl, subsequence($components, 2))
        )
    else
        ()
};

(: Helper function to recursively create a collection hierarchy. :)
declare function local:mkcol($collection, $path) {
    local:mkcol-recursive($collection, tokenize($path, "/"))
};

(: store the collection configuration for the app and the data collection :)
local:mkcol("/db/system/config/db", "@data.dir@"),
local:mkcol("/db/system/config/db/apps", "@app.name@"),
xmldb:store("/system/config/db/@data.dir@", "collection.xconf", doc($target||"/data.collection.xconf")),
xmldb:store("/system/config/db/apps/@app.name@", "collection.xconf", doc($target||"/app.collection.xconf")),

(: create 'editors' group that can edit all tablets :)
if (not(sm:group-exists("cfdbEditors")))
then sm:create-group("cfdbEditors")
else (),

(: create 'annotators' group that can edit only own tablets :)
if (not(sm:group-exists("cfdbAnnotators")))
then sm:create-group("cfdbAnnotators")
else (),

(: create 'readers' group that have only read access :)
if (not(sm:group-exists("cfdbReaders")))
then sm:create-group("cfdbReaders")
else (),

(: create a system user with dba rights that can write to the file system:)
if (not(sm:group-exists("@system.account.user@")))
then sm:create-group("@system.account.user@")
else (),
if (not(sm:user-exists("@system.account.user@")))
then sm:create-account("@system.account.user@", "@system.account.pwd@", "@system.account.user@", "dba", "CFDB System User", "CFDB System User")
else (),
sm:add-group-manager("@system.account.user@", "@system.account.user@"),


(: ACL for data collection :)
local:mkcol("/db", "@data.dir@"),
sm:chgrp(xs:anyURI("/db/@data.dir@"), "cfdbEditors"),
sm:chmod(xs:anyURI("/db/@data.dir@"), "rwxrwxr-x"),
sm:add-group-ace(xs:anyURI("/db/@data.dir@"), "cfdbAnnotators", true(), "r-x"),


(: create tablets collection :)
local:mkcol("/db", "@data.dir@/tablets"),

(: ACL for tablets collection:)
sm:chgrp(xs:anyURI("/db/@data.dir@/tablets"), "cfdbEditors"),
sm:chmod(xs:anyURI("/db/@data.dir@/tablets"), "rwxrwxr-x"),
sm:add-group-ace(xs:anyURI("/db/@data.dir@/tablets"), "cfdbAnnotators", true(), "rwx"),

local:mkcol("/db", "@data.dir@/etc/stdSigns/imgs"),
if (not(doc-available("/db/@data.dir@/etc/persons.xml")))
then xmldb:store("/db/@data.dir@/etc", "persons.xml", doc($target||"/data/etc/persons.xml"))
else (),
if (not(doc-available("/db/@data.dir@/etc/places.xml")))
then xmldb:store("/db/@data.dir@/etc", "places.xml", doc($target||"/data/etc/places.xml"))
else (),
if (not(doc-available("/db/@data.dir@/etc/taxonomies.xml")))
then xmldb:store("/db/@data.dir@/etc", "taxonomies.xml", doc($target||"/data/etc/taxonomies.xml"))
else (),
if (not(doc-available("/db/@data.dir@/etc/stdSigns/stdSigns.xml")))
then xmldb:store("/db/@data.dir@/etc/stdSigns", "stdSigns.xml", doc($target||"/data/etc/stdSigns/stdSigns.xml"))
else (),

for $file in xmldb:get-child-resources("/db/@data.dir@/etc")
return
(sm:chgrp(xs:anyURI("/db/@data.dir@/etc/"||$file), "cfdbEditors"), sm:chmod(xs:anyURI("/db/cfdb-data/etc/"||$file), "rwxrwxr-x"), sm:add-group-ace(xs:anyURI("/db/cfdb-data/etc/"||$file), "cfdbAnnotators", true(), "rwx")),

local:mkcol("/db", "@data.dir@/etc/stdSigns/imgs"),
sm:chgrp(xs:anyURI("/db/@data.dir@/etc"), "cfdbEditors"), sm:chmod(xs:anyURI("/db/@data.dir@/etc"), "rwxrwxr-x"), sm:add-group-ace(xs:anyURI("/db/@data.dir@/etc"), "cfdbAnnotators", true(), "rwx"),
sm:chgrp(xs:anyURI("/db/@data.dir@/etc/stdSigns"), "cfdbEditors"), sm:chmod(xs:anyURI("/db/@data.dir@/etc/stdSigns"), "rwxrwxr-x"), sm:add-group-ace(xs:anyURI("/db/@data.dir@/etc/stdSigns"), "cfdbAnnotators", true(), "rwx"),
sm:chgrp(xs:anyURI("/db/@data.dir@/etc/stdSigns/imgs"), "cfdbEditors"), sm:chmod(xs:anyURI("/db/@data.dir@/etc/stdSigns/imgs"), "rwxrwxr-x"), sm:add-group-ace(xs:anyURI("/db/@data.dir@/etc/stdSigns/imgs"), "cfdbAnnotators", true(), "rwx"),


(: create snapshot repository and set ACL :)
local:mkcol("/db", "@data.dir@/archive"),
sm:chgrp(xs:anyURI("@data.dir@/archive"), "cfdbEditors"),
sm:chmod(xs:anyURI("@data.dir@/archive"), "rwxrwxr-x"),



(: grant 'read' and 'execute' permissions on restxq endpoint module to editors and annotators :)
sm:add-group-ace(xs:anyURI($target||"/modules/api.xqm"), "cfdbAnnotators", true(), "r-x"),
sm:add-group-ace(xs:anyURI($target||"/modules/api.xqm"), "cfdbEditors", true(), "r-x"),
(: revoke exec rights from guest on api.xqm :)
sm:chmod(xs:anyURI($config:app-root||"/modules/api.xqm"), "rwxr-xr--"),

(: make configuration file $app-root/conf.xml owned by editors group:)
sm:chgrp(xs:anyURI($config:app-root||"/config.xml"), "cfdbEditors"),
sm:chmod(xs:anyURI($config:app-root||"/config.xml"), "rwxrwxr-x"),

(: grant 'read' and execute' permission on xql-scripts in api-collection:)
for $resource in xmldb:get-child-resources($config:app-root||"/api")
return (
    sm:add-group-ace(xs:anyURI($config:app-root||"/api/"||$resource), "cfdbAnnotators", true(), "r-x"),
    sm:add-group-ace(xs:anyURI($config:app-root||"/api/"||$resource), "cfdbEditors", true(), "r-x")
),


(: FOR TESTING PURPOSES ONLY Create default editor user :)
sm:create-account("edi", "pwd", "cfdbEditors")
