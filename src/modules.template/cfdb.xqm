xquery version "3.0";

module namespace cfdb = "@app.uri@/db";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

import module namespace config = "@app.uri@/config" at "xmldb:exist:///db/apps/@app.name@/modules/config.xqm";


(:~ module containing functions and variables common to the model on database level
 : NB configuration options are set under config.xqm
 :)
 
(: lists all standard signs in the database :)
declare function cfdb:listStdSigns() as element(tei:char)* {
    let $data := $config:data-root||"/etc/stdSigns/stdSigns.xml"
    return doc($data)//tei:char
};


(: lists all tablets in the database :)
declare function cfdb:tablets() as element(tei:TEI)* {
    collection($config:tablets-root)//tei:TEI[tei:sourceDoc]
};
