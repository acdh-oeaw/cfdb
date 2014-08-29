xquery version "3.0";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "xml";
declare option output:media-type "text/xml";

import module namespace tablet="http://www.oeaw.ac.at/acdh/cuneidb/tablet" at "xmldb:exist:///db/apps/cuneidb/modules/tablet.xqm";

declare variable $data external;

let $post-data := util:parse($data),
    $tei := $post-data/tei:TEI
    
return tablet:extractGlyphs($tei) (:$tei:)