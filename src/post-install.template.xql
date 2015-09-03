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

(: create tablets collection :)
local:mkcol("/db", "@data.dir@/tablets"),
local:mkcol("/db", "@data.dir@/etc"),
xmldb:move($target||"/data/etc", "/db/@data.dir@"),

(: ACL for data collection :)
sm:chgrp(xs:anyURI("/db/@data.dir@"), "cfdbEditors"),
sm:add-group-ace(xs:anyURI("/db/@data.dir@"), "cfdbAnnotators", true(), "r-x"),

(: ACL for tablets collection:)
sm:chgrp(xs:anyURI("/db/@data.dir@/tablets"), "cfdbAnnotators"),
sm:add-group-ace(xs:anyURI("/db/@data.dir@/tablets"), "cfdbAnnotators", true(), "rwx"),

(: ACL for taxonomies et alt. :)
sm:add-group-ace(xs:anyURI("/db/@data.dir@/etc"), "cfdbAnnotators", true(), "rwx"),
for $resource in xmldb:get-child-resources("/db/@data.dir@/etc")
return sm:add-group-ace(xs:anyURI("/db/@data.dir@/etc/"||$resource), "cfdbAnnotators", true(), "rwx"),

(: ACL for STANDARD SIGNS:)
sm:add-group-ace(xs:anyURI("/db/@data.dir@/etc/stdSigns"), "cfdbAnnotators", true(), "rwx"),
sm:add-group-ace(xs:anyURI("/db/@data.dir@/etc/stdSigns/imgs"), "cfdbAnnotators", true(), "rwx"),
for $resource in xmldb:get-child-resources("/db/@data.dir@/etc/stdSigns")
return sm:add-group-ace(xs:anyURI("/db/@data.dir@/etc/stdSigns/"||$resource), "cfdbAnnotators", true(), "rwx"),


(: grant 'read' and 'execute' permissions on restxq endpoint module to annotators :)
sm:add-group-ace(xs:anyURI($target||"/modules/api.xqm"), "cfdbAnnotators", true(), "r-x"),
(: revoke exec rights from guest on api.xqm :)
sm:chmod(xs:anyURI($config:app-root||"/modules/api.xqm"), "rwxr-xr--") 