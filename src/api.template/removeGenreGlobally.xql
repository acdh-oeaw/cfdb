xquery version "3.0";

(:~ 
 : This XQuery removes a scribe from all instances in the database. 
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
let $genreName:= $input/envelope/data/tei:category/tei:catDesc
return 
    if ($genreName and $genreName != '')
    then
        let $occurences := collection($config:tablets-root)//tei:profileDesc/tei:textClass/tei:keywords[@scheme = 'local']/tei:term[. eq $genreName],
            $noOcc := count($occurences),
            $remove := update value $occurences with ""
        return 
            <envelope xmlns="" status="success">
                <data>{$input/envelope/data/tei:category}</data>
                <msg>{"Removed "||$noOcc||" references to genre '"||$genreName||"'."}</msg>
            </envelope>
            
    else 
        <envelope xmlns="" status="failure">
                <data>{$input/envelope/data/tei:category}</data>
                <msg>Genre could not be determined, database has not been altered.</msg>
            </envelope>