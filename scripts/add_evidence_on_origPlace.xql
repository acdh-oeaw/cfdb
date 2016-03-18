xquery version "3.0";

declare default element namespace "http://www.tei-c.org/ns/1.0";

update insert attribute evidence {"external"} into collection("/db/cfdb-data/tablets")//origPlace/placeName[contains(.,"(")]
update insert attribute evidence {"internal"} into collection("/db/cfdb-data/tablets")//origPlace/placeName[not(contains(.,"("))]
for $o in collection('/db/cfdb-data/tablets')//tei:origPlace/tei:placeName[contains(.,'(')]
return update value $o with replace($o, "[\(\)]", "")