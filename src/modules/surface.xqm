xquery version "3.0";

module namespace surface = "http://www.oeaw.ac.at/acdh/cfdb/surface";

import module namespace config = "http://www.oeaw.ac.at/acdh/cfdb/config" at "xmldb:exist:///db/apps/cfdb/modules/config.xqm";
import module namespace cfdb = "http://www.oeaw.ac.at/acdh/cfdb/db" at "xmldb:exist:///db/apps/cfdb/modules/cfdb.xqm";
import module namespace tablet = "http://www.oeaw.ac.at/acdh/cfdb/tablet" at "xmldb:exist:///db/apps/cfdb/modules/tablet.xqm";
import module namespace annotation = "http://www.oeaw.ac.at/acdh/cfdb/annotations" at "xmldb:exist:///db/apps/cfdb/modules/annotations.xqm";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

(:~ stores a new surface image to the database and inserts a tei:surface element pointing to it
 : @param $tablet-id the id of the tablet
 : @param $width the width of the image to be stored
 : @param $height the height of the image to be stored
 : @param $data the image data 
 : @return a map with a mandatory "status" key ("success"|"error") and an optional "msg" key
 :)
declare function surface:new($tablet as element(tei:TEI), $type as xs:string?, $filename as xs:string?,  $width as xs:integer, $height as xs:integer, $data as item()) as map() {   
    let $tablet-id := tablet:id($tablet),   
        $path := tablet:path($tablet),
        $ext := 
            switch(true())
                case (lower-case($type) = 'image/jpeg') return 'jpg'
                case (lower-case($type) = 'image/tiff') return 'tiff'
                case (lower-case($type) = 'image/png') return 'png'
                case ($filename != '') return tokenize($filename,'\.')[last()]
                default return false(),
        (:$url := util:uuid()||"."||$ext:)
        $url := xmldb:encode-uri($filename)
    return 
    if ($url = tablet:listSurfaces($tablet)/tei:graphic/xs:string(@url))
    then map{"status" := "error", "msg" := "Surface exists already for this image."}
    else 
        let $store := if ($ext) 
            then 
                let $path := xmldb:store($path, $url, $data),
                    $ace := 
                        if ($path)
                        then (
                            sm:add-group-ace(xs:anyURI($path), "cfdbAnnotators", true(), "r--"), 
                            sm:add-group-ace(xs:anyURI($path), "cfdbEditors", true(), "rw-"), 
                            sm:chmod(xs:anyURI($path), "rw-------")
                        )
                        else ()
                return $path
            else false()
        let $insert :=  
                if ($store and $store != '')
                then update insert <surface xmlns="http://www.tei-c.org/ns/1.0"><graphic url="{$url}" width="{$width}px" height="{$height}px"/></surface> into $tablet//tei:sourceDoc
                else ()
        return
            switch (true())
                case ($type = "" and $filename = "") return map{"status":= "error", "msg" := "either argument type or filename must be provided"}
                case ($store = "") return map{"status":= "error", "msg" := "could not store image at "||$path||"/"||$url}
                default return map{"status":= "success", "msg" := "Added new surface "||$url, "filename" := $url, "path" := $path||"/"||$url}
};


(:~deletes one tei:surface element and all the annotations it contains
 : @param $tablet the tablet to operate on as a tei:TEI element
 : @param $surface-id id of the surface (i.e. the @url on a tei:graphic that is subordinate to the tei:surface in question)   
 : @return a map with a mandatory "status" key ("success"|"error") and an optional "msg" key
 :)
declare function surface:delete($tablet as element(tei:TEI), $surface-id as xs:string) as map() {
    let $path := tablet:path($tablet),
        $surface := surface:get($tablet, $surface-id),
        $filename := $surface-id,
        $annotation-ids := $surface/tei:zone!substring-after(@corresp,'#context_')
    return 
        if (not(util:binary-doc-available($path||"/"||$filename)))
        then map{"status" := "error", "msg" := "file not available at "||$path||"/"||$filename}
        else 
            let $rm-img := 
                try {xmldb:remove($path, $filename)}
                catch * {map{"status" := "error", "msg" := "Could not delete file at "||$path||"/"||$filename}}
            let $rm-annotations := $annotation-ids!annotation:delete($tablet, $filename, .)
            let $rm-surface := update delete $surface
            return map{"status" := "success", "msg" := "removed surface "||$filename}
};


(:~retrieves the given surface in the given tablet
 : @param $tablet the tablet to operate on as a tei:TEI element 
 : @param $surface-id id of the surface (i.e. the @url on a tei:graphic that is subordinate to the tei:surface in question)   
 : @return a tei:surface element
 :)
declare function surface:get($tablet as element(tei:TEI), $surface-id as xs:string) as element(tei:surface)? {
    $tablet//tei:surface[tei:graphic/@url = $surface-id]
};


(:~checks whether the surface with the given surface-id is available in the given tablet
 : @param $tablet the tablet to operate on as a tei:TEI element 
 : @param $surface-id id of the surface (i.e. the @url on a tei:graphic that is subordinate to the tei:surface in question)   
 : @return a map with a mandatory "status" key ("success"|"error") and an optional "msg" key
 :)
declare function surface:exists($tablet as element(tei:TEI), $surface-id as xs:string) as xs:boolean {
    exists(surface:get($tablet, $surface-id))
};



(: lists all annotations from the given surface, optionally filtering :)
declare function surface:list-annotations($tablet as element(tei:TEI), $surface-id as xs:string) {
    surface:list-annotations($tablet, $surface-id, ())
};

(: lists all annotations from the given surface, optionally filtering :)
declare function surface:list-annotations($tablet as element(tei:TEI), $surface-id as xs:string, $filter as xs:string*) {
    let $tablet-id := tablet:id($tablet),
        $surface := surface:get($tablet, $surface-id)
    let $glyphs := 
        for $zone in reverse($surface/tei:zone)
            let $glyph-zone := $zone/tei:zone,
                $img := $glyph-zone/tei:graphic/xs:string(@url)            
            let $context-id := substring-after($zone/@corresp,'#')
            let $context := $tablet//tei:seg[@type='context'][@xml:id = $context-id],
                $glyph := $context/tei:g,
                $char := $tablet//tei:glyph[@xml:id = substring-after($glyph/@ana,'#')],
                $note := $tablet//tei:note[@target = "#"||$glyph/@xml:id]
            return 
                <annotation>
                    <uuid>{substring-after($context-id,'context_')}</uuid>
                    <tablet>{$tablet-id}</tablet>
                    <img>/exist/apps/cfdb/$app-root/data/tablets/{$tablet-id||"/"||$img}</img>
                    <surface>{$surface-id}</surface>
                    <x>{$glyph-zone/number(@ulx)}</x>
                    <y>{$glyph-zone/number(@uly)}</y>
                    <width>{number($glyph-zone/@lrx) - number($glyph-zone/@ulx)}</width>
                    <height>{number($glyph-zone/@lry) - number($glyph-zone/@uly)}</height>
                    <sign>{$glyph/xs:string(@type)}</sign>
                    <reading>{$glyph/text()}</reading>
                    <context>{annotation:renderContext($context)}</context>
                    <sequence>{$char/tei:charProp[tei:localName='sequence']/tei:value/text()}</sequence>
                    <note>{$note/text()}</note>
                </annotation>
    let $filtered := 
        if ($filter = '') 
        then $glyphs
        else $glyphs[some $x in descendant::* satisfies contains($x,$filter)]
    return $filtered
    (:let $response := <cfdb:response>{$filtered}</cfdb:response> 
    return util:serialize($response,"method=json"):)
(:    return $response:)
};