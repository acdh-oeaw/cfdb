xquery version "3.0";

module namespace cfdb = "http://www.oeaw.ac.at/acdb/cuneidb/db";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

import module namespace config = "http://www.oeaw.ac.at/acdh/cuneidb/config" at "xmldb:exist:///db/apps/cuneidb/modules/config.xqm";


(:~ module containing functions and variables common to the model on database level
 : NB configuration options are set under config.xqm
 :)
 

declare function cfdb:listStdSigns(){
    let $data := $config:data-root||"/etc/stdSigns/stdSigns.xml"
    let $chars := 
        for $c in doc($data)//tei:char
        let $name := $c/tei:charName/text()
        order by $name 
        return
            <sign>
                <id>{$c/xs:string(@xml:id)}</id>
                <n>{$c/xs:string(@n)}</n>
                <name>{$name}</name>
            </sign>
    let $response := <cfdb:response>{$chars}</cfdb:response>
    return util:serialize($response,"method=json")
};
