xquery version "3.0";

(:~ 
 : This XQuery removes a place from all instances in the database. 
 : TODO: When implementing a user/editor system, make sure that only 
 : editors can execute this script.   
~:)

declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "xml";
declare option output:media-type "text/xml";
declare option output:exclude-result-prefixes "tei";
declare option output:indent "no";

import module namespace tablet="@app.uri@/tablet" at "xmldb:exist://db/apps/@app.name@/modules/tablet.xqm";
import module namespace config="@app.uri@/config" at "xmldb:exist://db/apps/@app.name@/modules/config.xqm";

declare variable $data external;

let $input := util:parse($data)
let $data := $input/envelope/data
let $placeName:= $data/tei:place/tei:placeName/text()
let $log := util:log-app("DEBUG", "cfdb", $input)
return
    switch (true())
        case (not($placeName) or $placeName = '') return
            <envelope xmlns="" status="failure">
                <data>{$data/*}</data>
                <msg>Place name could not be determined, database has not been altered.</msg>
            </envelope> 
            
        default return 
            let $occurences := collection($config:tablets-root)//tei:placeName[. eq $placeName],
                $noOcc := count($occurences),
                $remove := update value $occurences with ""
            return 
                <envelope xmlns="" status="success">
                    <data>{$data/*}</data>
                    <msg>{"Removed "||$noOcc||" references to place "||$placeName||"."}</msg>
                </envelope>