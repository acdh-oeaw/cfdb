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

import module namespace tablet="@app.uri@/tablet" at "xmldb:exist://db/apps/@app.name@/modules/tablet.xqm";
import module namespace config="@app.uri@/config" at "xmldb:exist://db/apps/@app.name@/modules/config.xqm";

declare variable $data external;

let $input := try{util:parse($data)}
                catch*{false()}
let $log := util:log("info", $input)
return 
    if (not($input)) 
    then <category xmlns="http://www.tei-c.org/ns/1.0">
            <catDesc newName="" nameToChange=""/>
         </category>
    else
    (:if (data($input//tei:catDesc/@newname) = "" or data($input//tei:catDesc/@nameToChange))
    then:)
        let $newName:= data($input//tei:catDesc/@newName)
        let $oldName:= data($input//tei:catDesc/@nameToChange)
        let $oldID := $input//tei:catDesc/text()
        let $newID := concat('genre_',lower-case(replace($newName,'\C','')))
        let $log := util:log("INFO", concat("newName: ",$newName))
        let $log := util:log("INFO", concat("oldName: ",$oldName))
        let $log := util:log("INFO", concat("oldID: ",$oldID))
        let $log := util:log("INFO", concat("newID: ",$newID))
        (:let $taxOcc := collection($config:data-root)//tei:encodingDesc/tei:classDecl/tei:taxonomy[@xml:id = 'genres']/tei:category[@xml:id = $oldID],
            $log := util:log("INFO", concat("taxOcc: ",$taxOcc/@xml:id)),
            $changeID := update value $taxOcc/@xml:id with $newID,
            $changeValue := update value $taxOcc/tei:catDesc/text() with $newName:)
        let $occurences := collection($config:tablets-root)//tei:textClass/tei:keywords[@scheme = 'local']/tei:term[. eq $oldName],
            $noOcc := count($occurences),
            $remove := update value $occurences with $newName
        return 
         <category xmlns="http://www.tei-c.org/ns/1.0">
            <catDesc newName="{$newName}" nameToChange="{$oldName}">{$newName}</catDesc>
         </category> 
    (:else <category xmlns="http://www.tei-c.org/ns/1.0">
            <catDesc newName="" nameToChange="">Ups, something went wrong</catDesc>
         </category> :)