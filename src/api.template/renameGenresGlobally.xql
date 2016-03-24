xquery version "3.0";

(:~ 
 : This XQuery renames a genre in all instances in the database.   
~:)

declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "xml";
declare option output:media-type "text/xml";
declare option output:exclude-result-prefixes "tei";
declare option output:indent "no";

import module namespace tablet="http://www.oeaw.ac.at/acdh/cfdb2/tablet" at "xmldb:exist://db/apps/cfdb/modules/tablet.xqm";
import module namespace config="http://www.oeaw.ac.at/acdh/cfdb2/config" at "xmldb:exist://db/apps/cfdb/modules/config.xqm";

declare variable $data external;

let $input := try{util:parse($data)}
                catch*{false()}
let $log := util:log("info", $input)
return 
    if (not($input)) then <data xmlns="" newName="parsing input failed"><tei:person role="scribe"><tei:persName/></tei:person><tei:note type="returnMsg">parsing input failed</tei:note></data> 
    else
    if (data($input//tei:catDesc/@newname) = "" or data($input//tei:catDesc/@nameToChange))
    then
        let $newName:= data($input//tei:catDesc/@newname)
        let $oldName:= data($input//tei:catDesc/@nameToChange)
        let $oldID := $input//tei:catDesc/text()
        let $occurences := collection($config:tablets-root)//tei:textClass/tei:keywords[@scheme = 'local']/tei:term[. eq $oldName],
            $noOcc := count($occurences),
            $remove := update value $occurences with $newName
        return 
         <category xmlns="http://www.tei-c.org/ns/1.0">
            <catDesc newName="{$newName}" nameToChange="{$oldName}"/>
         </category> 
    else <category xmlns="http://www.tei-c.org/ns/1.0">
            <catDesc newName="" nameToChange="">Ups, something went wrong</catDesc>
         </category> 