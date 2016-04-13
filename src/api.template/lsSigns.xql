xquery version "3.0";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

import module namespace config="@app.uri@/config" at "xmldb:exist:///db/apps/@app.name@/modules/config.xqm";
import module namespace cfdb="@app.uri@/cfdb" at "xmldb:exist:///db/apps/@app.name@/modules/cfdb.xqm";
import module namespace tablet="@app.uri@/tablet" at "xmldb:exist:///db/apps/@app.name@/modules/tablet.xqm";


(: lists all tei:g elements in the whole dataset :)

declare variable $data external;

let $log := util:log-app("DEBUG", $config:app-name, "lsSigns.xql called by " ||xmldb:get-current-user())
let $type := util:parse($data)/tei:charName/xs:string(.)
let $signs := cfdb:list-annotations("sign-type", $type)
return $signs