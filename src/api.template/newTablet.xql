xquery version "3.0";

(:~ 
 : This XQuery creates a new tablet in the database.
 : Each tablet is represented by a "main" TEI document
 : and several "surface" TEI documents that are edited 
 : with the Image Markup Tool.
 : 
~:)

declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "xml";
declare option output:media-type "text/xml";
declare option output:exclude-result-prefixes "tei";

import module namespace tablet="@app.uri@/tablet" at "xmldb:exist:///db/apps/@app.name@/modules/tablet.xqm";
import module namespace config="@app.uri@/config" at "xmldb:exist:///db/apps/@app.name@/modules/config.xqm";

declare variable $data external;

(: get the information inserted into the form :)
let $input := util:parse($data),
    $tei := $input/newTablet/data/tei:TEI
    
(: prepare collection and store TEI :)
let $newTablet := tablet:new($tei)
return 
    if (map:get($newTablet,'outcome'))
    then  
        <newTablet status="processed" xmlns="">
        	<data>{$tei}</data>
            <message>{$newTablet("message")} Please upload your images now.</message>
        </newTablet>
    
    else  
        <newTablet status="processed" xmlns="">
            <data>{$tei}</data>
            <message>{$newTablet("message")}</message>
        </newTablet>
