xquery version "3.0";

(:~ 
 : This XQuery removes a period from all instances in the database. 
 : TODO: parametrize and merge with other "remove*Globally" scripts
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
let $periodID := $input/data/@period
return 
    if ($periodID and $periodID != '')
    then
        let $occurences := collection($config:tablets-root)//tei:creation/tei:origDate/tei:date/@period[. eq $periodID],
            $noOcc := count($occurences),
            $remove := update value $occurences with ""
        return 
            <data period="{$periodID}" xmlns="">
                <tei:note type="returnMsg">{"Removed "||$noOcc||" references to period "||$periodID||"."}</tei:note>
            </data>
            
    else 
        <data xmlns="">
            <note type="returnMsg" xmlns="http://www.tei-c.org/ns/1.0">Period could not be determined, database has not been altered.</note>
        </data> 