xquery version "3.0";

module namespace cfdb = "http://www.oeaw.ac.at/acdh/cfdb/db";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

import module namespace config = "http://www.oeaw.ac.at/acdh/cfdb/config" at "xmldb:exist:///db/apps/cfdb/modules/config.xqm";


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
    let $user := xmldb:get-current-user()
    let $tablets := cfdb:tablets()
    let $data := 
    cfdb:array(
        for $t in $tablets
        let $filename := util:document-name($t),
            $path := util:collection-name($t),
            $permissions := sm:get-permissions($path),
            $editable := if ($permissions/*/@owner = $user or $user = $config:superusers) then true() else false() 
        let $id := $t//tei:msIdentifier/tei:idno,
            $title := $t/tei:teiHeader/tei:fileDesc/tei:titleStmt/data(tei:title),
            $region := $t//tei:msIdentifier/tei:region,
            $archive := $t//tei:collection[@type = "archive"],
            $dossier := $t//tei:collection[@type = "dossier"],
            $scribe := $t//tei:persName[@role = "scribe"],
            $city := $t//tei:origPlace/tei:placeName,
            $period := $t//tei:origDate/tei:date[@calendar = '#gregorian']/xs:string(@period),
            $anteQuem := $t//tei:origDate/tei:date[@calendar = '#gregorian']/xs:string(@notAfter),
            $postQuem := $t//tei:origDate/tei:date[@calendar = '#gregorian']/xs:string(@notBefore),
            $date := $t//tei:origDate/tei:date[@calendar = '#gregorian'],
            $dateBabylonian := $t//tei:origDate/tei:date[@calendar = '#babylonian'],
            $ductus := $t//tei:f[@name = "ductus"]/tei:symbol/xs:string(@value)
        return cfdb:object((
            cfdb:property("id", $id),
            cfdb:property("region", $region),
            cfdb:property("archive", $archive),
            cfdb:property("dossier", $dossier),
            cfdb:property("scribe", $scribe),
            cfdb:property("city", $city),
            cfdb:property("period", $period),
            cfdb:property("anteQuem", $anteQuem),
            cfdb:property("postQuem", $postQuem),
            cfdb:property("date", $date),
            cfdb:property("dateBabylonian", $dateBabylonian),
            cfdb:property("ductus", $ductus),
            cfdb:property("editable", $editable)
        ))
    )
    return cfdb:object((
        cfdb:property("data", $data),
        cfdb:property("itemsCount", count($tablets))
    ))
};


declare %private function cfdb:array($objects as xs:string*) {
    concat("[", string-join($objects, ","), "]") 
};


declare %private function cfdb:object($properties as xs:string*) {
    concat("{", string-join($properties, ","), "}") 
}; 

declare %private function cfdb:property($key as xs:string, $value) {
    concat(
        '"',$key,'"',
        ':',
        switch(true())
            case (starts-with($value, '[')) return () 
            case ($value instance of xs:integer) return ()
            default return  '"',
        replace($value,"(['])","\\$1"),
        switch(true())
            case (starts-with($value, '[')) return () 
            case ($value instance of xs:integer) return ()
            default return  '"'
    )
}; 
