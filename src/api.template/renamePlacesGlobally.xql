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

import module namespace tablet="@app.uri@/tablet" at "xmldb:exist:///db/apps/@app.name@/modules/tablet.xqm";
import module namespace config="@app.uri@/config" at "xmldb:exist:///db/apps/@app.name@/modules/config.xqm";

declare variable $data external;

(:
        <xf:instance xmlns="" id="renamePlaceOfIssue">
            <place xmlns="http://www.tei-c.org/ns/1.0" xml:id="currentPlace" oldName="">
                <placeName/>
                <note/>
            </place>
        </xf:instance>
:)

let $input := try{util:parse($data)}
                catch*{false()}
let $log := util:log("INFO", $input//tei:placeName)
return     
        if (not($input)) then 
            <place xmlns="http://www.tei-c.org/ns/1.0" xml:id="currentPlace" oldName="">
                <placeName/>
                <note>parsing input failed</note>
             </place> 
         else
         let $oldname := $input//tei:place/@oldName
         let $newName := $input//tei:placeName/text()
         let $occurences := collection($config:tablets-root)//tei:origPlace/tei:placeName[text() eq $oldname]
         let $log := util:log("INFO", count($occurences)||" occurences")
         let $noOcc := count($occurences)
         let $rename := try { update value $occurences with $newName } catch * {$err:code||": "||$err:description||". Data: "||$err:value}
         let $log := util:log("INFO", "CHECK")
         let $log := util:log("INFO",string-join(for $o in $occurences return $o/root()/tei:TEI/@xml:id, ', '))
         let $log := util:log("INFO", $rename)
         let $log := util:log("INFO", "newName:"||$newName||", oldName:"||$oldname)
         return 
             <place xmlns="http://www.tei-c.org/ns/1.0" oldName="{$oldname}">
                <placeName>{$newName}</placeName>
                <note>{$noOcc||" occurences of "||$oldname||" into "||$newName||"."}</note>
             </place> 