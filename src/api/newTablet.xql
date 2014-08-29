xquery version "3.0";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "xml";
declare option output:media-type "text/xml";
declare option output:exclude-result-prefixes "tei";

import module namespace tablet="http://www.oeaw.ac.at/acdh/cuneidb/tablet" at "xmldb:exist:///db/apps/cuneidb/modules/tablet.xqm";
import module namespace config="http://www.oeaw.ac.at/acdh/cuneidb/config" at "xmldb:exist:///db/apps/cuneidb/modules/config.xqm";

declare variable $data external;

declare function local:move-to-db($id as xs:string, $img-path as xs:string, $filename as xs:string, $mediatype as xs:string) as item() {
    let $log := util:log("INFO", "local:move-to-db()")
    return
    if (some $p in ($id, $img-path, $filename, $mediatype) satisfies $p = "")
    then 
        let $log := util:log("INFO", "local:move-to-db() some parameter is empty")
        return false()
    else system:as-user('cuneiformDBSystem', 'sEN5)u#)~Tn!3E6ZkCW{J9e',
        try {
            let $segment := substring-after($img-path, 'upload/')
            let $file-path := '/opt/exist/webapp/upload/'||$segment
            let $extension := tokenize($filename,'\.')[last()]
            let $exists := file:exists($file-path)
            let $log := util:log("INFO", "file-path: "||$file-path)
            let $log := util:log("INFO",concat("exists: ",if($exists) then 'yes' else 'no'))
            return
                if ($exists)
                then 
                    let $content := file:read-binary($file-path)
                    return xmldb:store($config:data-root||"/tablets", $id||"."||$extension ,$content, $mediatype)
                else false()
                
        } catch * {
            let $log := util:log("INFO", "local:move-to-db() something went wrong")
            return false()
        }
    )
};

let $input := util:parse(replace($data,'tei:','')),
    $tei := $input/newTablet/data/tei:TEI,
    $tei-prefRmvd := transform:transform($tei,doc('rmNsPrefixes.xsl'),()),
    $id := $tei/xs:string(@xml:id),
    $img := $input/newTablet/img,
    $img-path := util:unescape-uri($img/text(),"UTF-8"),
    $log := util:log("INFO", "img-path: "||$img-path),
    $filename := $img/xs:string(@filename),
    $mediatype := $img/xs:string(@mediatype),
    $extension := tokenize($filename,'\.')[last()]

let $log := util:log("INFO","$filename:"|| $filename)
let $log := 
    for $p in ("$filename","$mediatype", "$extension")
    return util:log("INFO", $p||": "||util:eval($p))


let $store-tei := 
        try {
            xmldb:store($config:data-root||"/tablets",$id||".xml",$tei-prefRmvd)
        } catch * {
            ()
        }

let $store-img := local:move-to-db($id, $img-path, $filename, $mediatype) 
    
return 
    if ($store-tei and $store-img)
    then 
        let $tei:graphic := doc($store-tei)/tei:TEI/tei:facsimile[1]/tei:surface[1]/tei:graphic[1]
        let $img-width := image:get-width(util:binary-doc($store-img)),
            $img-height := image:get-height(util:binary-doc($store-img))
        
        let $set-filename := update value $tei:graphic/@url with concat($id,'.',$extension),
            $set-img-width:= update value $tei:graphic/@width with concat($img-width,"px"),
            $set-img-height := update value $tei:graphic/@height with concat($img-height,"px")
    
        return 
            <newTablet status="processed">
                <data>{$store-tei}</data>
                <img>{$store-img}</img>
                <message>Stored tablet with ID {data($tei/@xml:id)} to the database at {$store-img}</message>
            </newTablet>
    else 
        <newTablet status="processed">
            <data></data>
            <img></img>
            <message>an error occured</message>
        </newTablet>
