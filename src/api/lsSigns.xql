xquery version "3.0";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

import module namespace config="http://www.oeaw.ac.at/acdh/cuneidb/config" at "xmldb:exist:///db/apps/cuneidb/modules/config.xqm";
import module namespace tablet="http://www.oeaw.ac.at/acdh/cuneidb/tablet" at "xmldb:exist:///db/apps/cuneidb/modules/tablet.xqm";
import module namespace api="http://www.oeaw.ac.at/acdh/cuneidb/api" at "xmldb:exist:///db/apps/cuneidb/modules/api.xqm";

let $data := 
    for $g in collection($config:tablets-root)//tei:g
    return 
        map {
            "id" := xs:string($g/@xml:id),
            "type" := xs:string($g/@type),
            "reading" := xs:string($g),
            "text reference" := root($g)//tei:msIdentifier/tei:idno/xs:string(.),
            "period" := root($g)//tei:origDate/tei:date/xs:string(@period),
            "place" := root($g)//tei:origPlace/tei:placeName/xs:string(.)
        }

return api:response('lsSigns.xql',$data)