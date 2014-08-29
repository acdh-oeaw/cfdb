xquery version "3.0";

declare namespace api = "http://acdh.oeaw.ac.at/cuneidb/api";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "xml";
declare option output:media-type "text/xml";

(:import module namespace tablet = "http://www.oeaw.ac.at/acdh/cuneidb/tablet" at "../modules/tablet.xqm";:)
(:tablet:list():)
  
let $datapath := "/db/apps/cuneidb/data"
let $data := collection($datapath||"/tablets")//tei:TEI[tei:text/@type='tablet']
return 
    <tablets xmlns="">{
        for $d in $data
            let $id := $d/@xml:id, 
                $title := $d/tei:teiHeader/tei:fileDesc/tei:titleStmt/data(tei:title),
                $path := base-uri($d),
                $img-path := util:collection-name($d)||"/"||$d/tei:facsimile[1]/tei:surface[1]/tei:graphic[1]/@url
        return
        <tablet>
            <id>{$d/data(@xml:id)}</id>
            <title>{$title}</title>
            <path>{$path}</path>
            <img-path>{$img-path}</img-path>
        </tablet>
    }</tablets>
