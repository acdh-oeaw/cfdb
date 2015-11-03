xquery version "3.0";

module namespace cfdb = "@app.uri@/db";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

import module namespace config = "@app.uri@/config" at "xmldb:exist:///db/apps/@app.name@/modules/config.xqm";


(:~ module containing functions and variables common to the model on database level
 : NB configuration options are set under config.xqm
 :)
declare variable $cfdb:stdSigns :=  
    for $s at $pos in cfdb:listStdSigns()
    let $n := xs:integer(replace($s/@n,'[a-z\s\*]','')) 
    order by $n ascending
    return $s;

declare variable $cfdb:stdSign-position-by-charname := 
    map:new(
        for $s at $pos in $cfdb:stdSigns
        return map:entry($s/tei:charName, $pos)
    );
    
declare variable $cfdb:stdSign-by-position := 
    map:new(
        for $s at $pos in $cfdb:stdSigns
        return map:entry($pos, $s)
    );
    
declare function cfdb:stdSign-by-charname($n as xs:string) {
    let $data := $config:data-root||"/etc/stdSigns/stdSigns.xml"
    return doc($data)//tei:char[tei:charName = $n]
};
 
(: lists all standard signs in the database :)
declare function cfdb:listStdSigns() as element(tei:char)* {
    let $data := $config:data-root||"/etc/stdSigns/stdSigns.xml"
    return doc($data)//tei:char
};


(: lists all tablets in the database :)
declare function cfdb:tablets() as element(tei:TEI)* {
    collection($config:tablets-root)//tei:TEI[tei:sourceDoc]
};

(: returns an JSON representation of all tablets in the database :)
declare function cfdb:tabletsAsJSON() as xs:string {
    cfdb:array(
        for $t in cfdb:tablets() 
        return cfdb:object((
            cfdb:property("id", $t//tei:msIdentifier/tei:idno),
            cfdb:property("region", $t//tei:msIdentifier/tei:region),
            cfdb:property("archive", $t//tei:collection[@type = "archive"]),
            cfdb:property("dossier", $t//tei:collection[@type = "dossier"]),
            cfdb:property("scribe", $t//tei:persName[@role = "scribe"]),
            cfdb:property("city", $t//tei:origPlace/tei:placeName),
            cfdb:property("period", $t//tei:origDate/tei:date[@calendar = '#gregorian']/xs:string(@period)),
            cfdb:property("anteQuem", $t//tei:origDate/tei:date[@calendar = '#gregorian']/xs:string(@notAfter)),
            cfdb:property("postQuem", $t//tei:origDate/tei:date[@calendar = '#gregorian']/xs:string(@notBefore)),
            cfdb:property("date", $t//tei:origDate/tei:date[@calendar = '#gregorian']),
            cfdb:property("dateBabylonian", $t//tei:origDate/tei:date[@calendar = '#babylonian']),
            cfdb:property("ductus", $t//tei:f[@name = "ductus"]/tei:symbol/xs:string(@value))
        ))
    )
};


declare %private function cfdb:array($objects as xs:string*) {
    concat("[", string-join($objects, ","), "]") 
}; 


declare %private function cfdb:object($properties as xs:string*) {
    concat("{", string-join($properties, ","), "}") 
}; 

declare %private function cfdb:property($key as xs:string, $value as xs:string?) {
    concat("'",$key,"'",":'",replace($value,"(['])","\\$1"),"'")
}; 
