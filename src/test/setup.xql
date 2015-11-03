xquery version "3.0";

(:sm:create-account("daniel", "daniel", ("cfdbEditors", "cfdbAnnotators")),
sm:create-account("elmar", "elmar", "cfdbAnnotators")

sm:create-account("rPirngruber", "H!r@SW{4JMuZrG", ("cfdbEditors", "cfdbAnnotators")),
sm:create-account("mJursa", "Ae;nSAd4k[cDS(", ("cfdbEditors", "cfdbAnnotators")),:)


(: ACL for data collection :)
sm:chgrp(xs:anyURI("/db/cfdb-data"), "cfdbEditors"),
sm:add-group-ace(xs:anyURI("/db/cfdb-data"), "cfdbAnnotators", true(), "r-x"),

(: ACL for tablets collection:)
sm:chgrp(xs:anyURI("/db/cfdb-data/tablets"), "cfdbAnnotators"),
sm:add-group-ace(xs:anyURI("/db/cfdb-data/tablets"), "cfdbAnnotators", true(), "rwx"),

(: ACL for taxonomies et alt. :)
sm:add-group-ace(xs:anyURI("/db/cfdb-data/etc"), "cfdbAnnotators", true(), "rwx"),
for $resource in xmldb:get-child-resources("/db/cfdb-data/etc")
return sm:add-group-ace(xs:anyURI("/db/cfdb-data/etc/"||$resource), "cfdbAnnotators", true(), "rwx"),

(: ACL for STANDARD SIGNS:)
sm:add-group-ace(xs:anyURI("/db/cfdb-data/etc/stdSigns"), "cfdbAnnotators", true(), "rwx"),
sm:add-group-ace(xs:anyURI("/db/cfdb-data/etc/stdSigns/imgs"), "cfdbAnnotators", true(), "rwx"),
for $resource in xmldb:get-child-resources("/db/cfdb-data/etc/stdSigns")
return sm:add-group-ace(xs:anyURI("/db/cfdb-data/etc/stdSigns/"||$resource), "cfdbAnnotators", true(), "rwx")