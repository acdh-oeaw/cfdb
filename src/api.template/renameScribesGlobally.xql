xquery version "3.0";

(:~ 
 : This XQuery renames a scribe´s name in all instances in the database. 
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

let $input := try{util:parse($data)}
                catch*{false()}
let $log := util:log("info", $input)
return 
    if (not($input)) then <data xmlns="" newName="parsing input failed"><tei:person role="scribe"><tei:persName/></tei:person><tei:note type="returnMsg">parsing input failed</tei:note></data> 
    else
    if ($input//tei:persName = "" or $input/data/@newName)
    then
        let $scribeName := $input//tei:persName/text(),
            $newName := data($input/data/@newName),
            $log := util:log("INFO", $scribeName),
            $log := util:log("INFO", $newName),
            $occurences := collection($config:tablets-root)//tei:persName[@role = 'scribe'][text() eq $scribeName],
            $log := util:log("INFO", count($occurences)||" occurences"),
            $noOcc := count($occurences)
        let $rename := update value $occurences with $newName
        return <data xmlns="" newName="{$newName}"><tei:person role="scribe"><tei:persName/></tei:person><tei:note type="returnMsg">Renamed {$noOcc} references of {$scribeName} to {$newName}.</tei:note></data> 
    else <data xmlns="" newName="Scribe Name could not be determined"><tei:person role="scribe"><tei:persName/></tei:person><tei:note type="returnMsg">Scribe Name could not be determined, database has not been altered.</tei:note></data>