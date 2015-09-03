xquery version "3.0";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

import module namespace config="@app.uri@/config" at "xmldb:exist://db/apps/@app.name@/modules/config.xqm";
import module namespace tablet="@app.uri@/tablet" at "xmldb:exist://db/apps/@app.name@/modules/tablet.xqm";
import module namespace api="@app.uri@/api" at "xmldb:exist://db/apps/@app.name@/modules/api.xqm";

(: lists all tei:g elements in the whole dataset :)
let $log := util:log-app("DEBUG", $config:app-name, "lsSigns.xql called by " ||xmldb:get-current-user())
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