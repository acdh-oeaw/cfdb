xquery version "3.0";

module namespace annotation = "@app.uri@/annotations";

import module namespace config = "@app.uri@/config" at "xmldb:exist:///db/apps/@app.name@/modules/config.xqm";
import module namespace tablet = "@app.uri@/tablet" at "xmldb:exist:///db/apps/@app.name@/modules/tablet.xqm";

declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace cfdb = "@app.uri@";

(: TODO move to config module :)
declare variable $annotation:glyphs_relpath := "_glyphs";
declare variable $annotation:glyphs_img_extension := ".png";

(: RestXQ endpoints for JS image annotating :)

declare %private function annotation:json2tei($json as xs:string) {
    ()
};

declare %private function annotation:tei2json($element as element()) {
    ()
};

declare %private function annotation:mkContext($annotation-id as xs:string) as element(tei:seg) {
    annotation:mkContext($annotation-id,())
};

declare function annotation:mkContext($annotation-id as xs:string, $data as map()?) as element(tei:seg) {
    let $before := if (exists($data)) then $data("before") else "",
        $glyph := if (exists($data)) then $data("glyph") else "",
        $after := if (exists($data)) then $data("after") else "",
        $type := if (exists($data)) then $data("sign") else ""
    let $context := <seg xml:space="preserve" type="context" xml:id="context_{$annotation-id}" xmlns="http://www.tei-c.org/ns/1.0">{$before}<g type="{$type}" ana="#charDecl_{$annotation-id}" facs="#graphic_glyph_{$annotation-id}" xml:id="glyph_{$annotation-id}">{$glyph}</g>{$after}</seg>
    return $context
};


declare %private function annotation:mkCharDecl($annotation-id as xs:string) as element(tei:glyph) {
    <glyph xml:id="charDecl_{$annotation-id}" xmlns="http://www.tei-c.org/ns/1.0">
        <charProp>
            <localName>sequence</localName>
            <value/>
        </charProp>
    </glyph>
};

declare %private function annotation:mkNote($annotation-id as xs:string) as element(tei:note) {
    <note target="#glyph_{$annotation-id}" xmlns="http://www.tei-c.org/ns/1.0"/>
};

declare %private function annotation:mkZone($annotation-id as xs:string, $params as map()) as element(tei:zone) {
    let $ulx := $params("ulx"),
        $uly := $params("uly"),
        $lrx := $params("lrx"),
        $lry := $params("lry"),
        $filename := $params("filename")
    return
        <zone corresp="#context_{$annotation-id}" xmlns="http://www.tei-c.org/ns/1.0">
            <zone corresp="#glyph_{$annotation-id}" ulx="{$ulx}" uly="{$uly}" lrx="{$lrx}" lry="{$lry}">
                <graphic url="{$annotation:glyphs_relpath||"/"||$filename}" xml:id="graphic_glyph_{$annotation-id}"/>
            </zone>
        </zone>
};

(:parses json input to a XQuery map 
  WATCHME hard-coded handling of base64 encoded images unter the "img" field 
  since this caused jsonxq:parse() to hick up 
:)
declare %private function annotation:json2map($data as xs:string, $params as map()) as map() {
    let $datadec := util:base64-decode($data),
        $dataNormalized := replace($datadec,'(^\{|\}$)','')
    return 
        map:new((
            for $line in tokenize($dataNormalized,',') 
            let $key := substring-before(translate($line,'"',''),':'),
                $value := substring-after(translate($line,'"',''),':')
            return 
               if ($key != 'img')
               then map:entry($key, $value)
               else 
                    let $tabletpath := $params("tabletpath"),
                        $filename := $params("filename"),
                        $path := $tabletpath||"/"||$annotation:glyphs_relpath,
                        $mkPath := if (xmldb:collection-available($path)) then true() else xmldb:create-collection($tabletpath,$annotation:glyphs_relpath),
                        $img := replace(substring-after($dataNormalized,"data:image/png;base64,"),'(^"|"$)',''),
                        (: store base-64 encoded img :)
                        $img-filepath := xmldb:store($path,$filename,xs:base64Binary($img))
                    return ()
        ))
};


(: ********************************* :)
(: ********   ANNOTATIONS    ******* :)
(: ********************************* :)


declare function annotation:new($data as xs:string, $tablet as element(tei:TEI), $surface-id as xs:string) as xs:string? {
    switch(true())
        case $data = "" return false()
        default return
            let $annotation-id := annotation:getUUID()
            let $surface := $tablet//tei:surface[tei:graphic/@url = $surface-id]
                
            let $tabletpath := tablet:path($tablet),   
                $filename := normalize-space($annotation-id)||$annotation:glyphs_img_extension
            let $params := map{"tabletpath" := $tabletpath, "filename" := $filename}
            let $xdata := annotation:json2map($data, $params)
                
            let $ulx := round(number($xdata("x"))),
                $uly := round(number($xdata("y"))),
                $lrx := round($ulx + number($xdata("width"))),
                $lry := round($uly + number($xdata("height")))
        
            let $tei_zone_params := map{
                "ulx" := $ulx,
                "uly" := $uly,
                "lrx" := $lrx,
                "lry" := $lry,
                "filename" := $filename
            }
            
            let $tei_zone := annotation:mkZone($annotation-id, map:new(($xdata,$tei_zone_params)))
            let $tei_charDecl := annotation:mkCharDecl($annotation-id) 
            let $tei_context := annotation:mkContext($annotation-id)
            let $tei_note := annotation:mkNote($annotation-id)
            
            let $update := (
                update insert $tei_zone into $surface,
                update insert $tei_charDecl into $tablet//tei:charDecl,
                update insert $tei_context into $tablet//tei:body/tei:ab,
                update insert $tei_note into $tablet//tei:back,
                true()
            )
            
            return (
                let $response := 
                    if ($update)
                    then <cfdb:response><uuid>{$annotation-id}</uuid></cfdb:response>
                    else <cfdb:response><msg>Zone could not be annotated</msg></cfdb:response>
                return util:serialize($response,'method=json') 
            )
};



(:~ setter function for existing annotation
 : TODO refactor so that the function's signature matches the other ones, i.e. accept tablet as tei:TEI element  
 : @param $data the data to set 
 : @param $tablet-id the ID of the tablet to operate on
 : @param $surface-id the ID of the surface which contains the annotation
 : @param $annotation-id the ID of the annotation to update
 :)
declare function annotation:update($data as xs:string, $tablet-id as xs:string, $surface-id as xs:string, $annotation-id as xs:string) {
    switch(true())
        case $tablet-id = "" return false()
        case $surface-id = "" return false()
        case $data = "" return false()
        default return
            let $tablet := tablet:get($tablet-id),
                $surface := $tablet//tei:surface[tei:graphic/@url = $surface-id]
                
            let $tabletpath := tablet:path($tablet),   
                $filename := normalize-space($annotation-id)||$annotation:glyphs_img_extension
            
            let $params := map{"tabletpath" := $tabletpath, "filename" := $filename}
            let $xdata := annotation:json2map($data, $params)
                
            let $ulx := round(number($xdata("x"))),
                $uly := round(number($xdata("y"))),
                $lrx := round($ulx + number($xdata("width"))),
                $lry := round($uly + number($xdata("height")))
        
            let $tei_zone_params := map{
                "ulx" := $ulx,
                "uly" := $uly,
                "lrx" := $lrx,
                "lry" := $lry,
                "filename" := $filename
            }
            
            let $context-zone := $tablet//tei:zone[@corresp = '#context_'||$annotation-id],
                $glyph-zone := $context-zone/tei:zone,
                $glyph-img := $glyph-zone/tei:graphic/xs:string(@url),
                $context := annotation:context($tablet, $annotation-id),
                $glyph := $context/tei:g[1],
                $char := annotation:char($tablet, $annotation-id),
                $note := annotation:note($tablet, $annotation-id)
            
            let $update := (
                annotation:context($xdata,$tablet, $annotation-id),
                annotation:sequence($xdata, $tablet, $annotation-id),
                annotation:note($xdata, $tablet, $annotation-id)
            )
                            
            return true()
};


declare function annotation:read($tablet-id as xs:string) {
    ()
};

(: reads one annotation by its ID :)
declare function annotation:read($tablet as element(tei:TEI), $surface-id as xs:string, $annotation-id as xs:string, $filter as xs:string*) {
    let $tablet-id := tablet:id($tablet)
    let $context-zone := $tablet//tei:zone[@corresp = '#context_'||$annotation-id],
        $glyph-zone := $context-zone/tei:zone,
        $glyph-img := $glyph-zone/tei:graphic/xs:string(@url),
        $context := annotation:context($tablet, $annotation-id),
        $glyph := $context/tei:g[1],
        $char := annotation:char($tablet, $annotation-id),
        $note := annotation:note($tablet, $annotation-id)[1]
    
    let $data := 
        <annotation>
            <uuid>{$annotation-id}</uuid>
            <tablet>{$tablet-id}</tablet>
            <img>/exist/apps/@app.name@/$app-root/data/tablets/{$tablet-id||"/"||$glyph-img}</img>
            <surface>{$surface-id}</surface>
            <x>{$glyph-zone/number(@ulx)}</x>
            <y>{$glyph-zone/number(@uly)}</y>
            <width>{number($glyph-zone/@lrx) - number($glyph-zone/@ulx)}</width>
            <height>{number($glyph-zone/@lry) - number($glyph-zone/@uly)}</height>
            <sign>{$glyph/xs:string(@type)}</sign>
            <reading>{lower-case($glyph/text())}</reading>
            <context>{annotation:renderContext($context)}</context>
            <sequence>{$char/tei:charProp[tei:localName='sequence']/tei:value/text()}</sequence>
            <note>{$note/text()}</note>
        </annotation>
    return  
        if ($filter = '') 
        then $data
        else $data[some $x in descendant::* satisfies contains(lower-case($x),$filter)]
};


(:~ deletes the given annotation (glyph image and annotation data)
 : @param $tablet the tablet as a tei:TEI element
 : @return empty sequence
 :)
declare function annotation:delete($tablet as element(tei:TEI), $surface-id as xs:string, $annotation-id as xs:string) {
    let $context := annotation:context($tablet, $annotation-id), 
        $note := annotation:note($tablet, $annotation-id),
        $char := annotation:char($tablet, $annotation-id),
        $glyphZone := annotation:glyphZone($tablet, $annotation-id),
        $thumbnail_relpath := $glyphZone/tei:graphic/xs:string(@url),
        $thumbnail_filepath := replace(util:collection-name($tablet),'/$','')||"/"||$thumbnail_relpath,
        
        $thumbnail_path := util:collection-name($thumbnail_filepath),
        $thumbnail_filename := substring-after($thumbnail_filepath, $thumbnail_path||"/")
    
    return (
        update delete $glyphZone/parent::tei:zone,
        update delete $context,
        update delete $note,
        update delete $char,
        if (util:binary-doc-available($thumbnail_path||"/"||$thumbnail_filename))
        then xmldb:remove($thumbnail_path, $thumbnail_filename)
        else ()
    )
    
};

declare %private function annotation:glyphZone($tablet as element(tei:TEI), $annotation-id as xs:string) as element(tei:seg)?{
    let $zone := $tablet//tei:zone[@corresp = "#glyph_"||$annotation-id]
(:    let $log := util:log-app("DEBUG", $config:app-name, $context):)
    return $zone 
};

(: ****************************** :)
(: *********   CONTEXT  ********* :)
(: ****************************** :)

(:~ This function retrieves the context of a given annotation.
 : @param $g the tei:g element of the annotated glyph
 : @return annotation context as a string 
 :)
declare function annotation:context($g as element(tei:g)) as xs:string?{
    let $context := $g/parent::tei:seg[@type = 'context']
    return $context
};

(:~ This function retrieves the context of a given annotation.
 : @param $tablet tablet data as a tei:TEI element
 : @param $annotation-id the ID of the annotation 
 : @return a tei:seg element representing the context  
 :)
declare %private function annotation:context($tablet as element(tei:TEI), $annotation-id as xs:string) as element(tei:seg)?{
    let $context := $tablet//tei:seg[@type = 'context'][@xml:id = 'context_'||$annotation-id]
    return $context
};

(:~ This function sets the context of a given annotation.
 : @param $data a map containing the annotation data 
 : @param $tablet tablet data as a tei:TEI element
 : @param $annotation-id the ID of the annotation 
 : @return empty
 :)
declare %private function annotation:context($data as map(), $tablet as element(tei:TEI), $annotation-id as xs:string) as element(tei:seg)?{
    let $context-input := $data("context"), 
        $reading-input := $data("reading"),
        $sign-input := $data("sign")
    return
        if ($context-input = "" and $reading-input = "" and $sign-input = "")
        then ()
        else 
            let $context := annotation:context($tablet, $annotation-id),
                $contextParsed := 
                    if ($context-input != "" and $reading-input != "")
                    then annotation:parseContext($context-input, $reading-input)
                    else (),
                $new := annotation:mkContext($annotation-id, map:new(($contextParsed, $data)))
            return update replace $context with $new
};


(: ****************************** :)
(: ********   SEQUENCE    ******* :)
(: ****************************** :)

(:~ This function returns the tei:glyph element which serves as a wrapper for paleographic annotation data. 
 : @param $tablet tablet data as a tei:TEI element
 : @param $annotation-id the ID of the annotation 
 : @return tei:char element
 :)
declare %private function annotation:char($tablet as element(tei:TEI), $annotation-id as xs:string){
    let $char := $tablet//tei:glyph[@xml:id= 'charDecl_'||$annotation-id]
    return $char
};

(:~ This function sets the "sequence" value on the annotated glyph. 
 : @param $tablet tablet data as a tei:TEI element
 : @param $annotation-id the ID of the annotation 
 : @return empty
 :)
declare %private function annotation:sequence($data as map(), $tablet as element(tei:TEI), $annotation-id as xs:string){
    let $char := annotation:char($tablet, $annotation-id)
    return update value $char/tei:charProp[tei:localName = "sequence"]/tei:value with $data("sequence")
};


(:~ This function retrieves the "sequence" value of an annotated glyph 
 : @param $g the tei:g element of the annotated glyph 
 : @return sequence value as a string
 :)
 declare function annotation:sequence($g as element(tei:g)) as xs:string? {
    let $char := annotation:char($tablet, $annotation-id)
    return $char/tei:charProp[tei:localName = "sequence"]/tei:value/xs:string(.)
};




(:~ This function retrieves the standard sing name of an annotated glyph 
 : @param $g the tei:g element of the annotated glyph 
 : @return sequence value as a string
 :)
 declare function annotation:sign($g as element(tei:g)) as xs:string? {
    $g/@type/xs:string(.)
};


(: ****************************** :)
(: **********   NOTES   ********* :)
(: ****************************** :)

 
(:~ This function retrieves a freetext note that is attached to an annotated glyph 
 : @param $g the tei:g element of the annotated glyph 
 : @return note as a string
 :)
declare function annotation:note($g as element(tei:g)) as xs:string? {
    let $note := $tablet//tei:note[@target = "#"||$g/@xml:id]
    return 
        (if (count($note) gt 1)
        then util:log-app("WARN", $config:app-name, "more than one note for annotation "||$annotation-id)
        else (),
        $note[1]/xs:string(.))
};

(:~ This function retrieves a freetext note that is attached to an annotated glyph 
 : @param $tablet tablet data as a tei:TEI element
 : @param $annotation-id the ID of the annotation 
 : @return note as a tei:note element
 :)
declare %private function annotation:note($tablet as element(tei:TEI), $annotation-id as xs:string) as element(tei:note)?{
    let $note := $tablet//tei:note[@target = '#glyph_'||$annotation-id]
    return 
        (if (count($note) gt 1)
        then util:log-app("WARN", $config:app-name, "more than one note for annotation "||$annotation-id)
        else (),
        ($note)[1])
};

(:~ This function sets the content of a freetext note that is attached to an annotated glyph 
 : @param $tablet tablet data as a tei:TEI element
 : @param $annotation-id the ID of the annotation 
 : @return empty
 :)
declare %private function annotation:note($data as map(), $tablet as element(tei:TEI), $annotation-id as xs:string) as empty() {
    let $note := annotation:note($tablet, $annotation-id)
    return update value $note with $data("note")
};

declare %private function annotation:match-is-reading($match as element(fn:match)) as xs:boolean{
    let $ana := $match/parent::fn:analyze-string-result
    let $log := util:log-app("DEBUG", $config:app-name, $ana)
    return
        (: only one match in fn:analyze-string-result :)
        if (count($ana/fn:match) eq 1) 
        then true()
        else 
            if ($match/following-sibling::*[1]/self::fn:non-match[starts-with(.,'*')]) 
            then true()
            else 
                (: if there is a asterisk following anoter match, this is not our reading :)
                if (some $m in $ana/fn:match satisfies $m/following-sibling::*[1]/self::fn:non-match[starts-with(.,'*')])
                then false()
                else 
                    (: if there is no asterisk following any match, just take the first one :)
                    if (not($match/preceding-sibling::fn:match))
                    then true()
                    else false()
};

declare %private function annotation:highlightMatch($node as node()) {
    typeswitch($node)
        case element() return
            element {QName(namespace-uri($node), $node/name())} {(
                if ($node/self::fn:match and annotation:match-is-reading($node))
                then attribute is-reading {"true"}
                else (),
                for $n in $node/node()
                return annotation:highlightMatch($n)
            )}
        case document-node() return annotation:highlightMatch($node/*)
        default return $node
};


declare function annotation:parseContext($context as xs:string, $reading as xs:string) as map() {
    if ($context = '' or $reading = '')
    then ()
    else 
        let $ana := fn:analyze-string($context, $reading, "i")
        let $highlighted := annotation:highlightMatch($ana)
        let $before := replace(string-join($highlighted/fn:match[@is-reading='true']/preceding-sibling::*,''),'\s+',' '),
            $glyph := $highlighted/fn:match[@is-reading='true']/text(),
            $after := replace(replace(string-join($highlighted/fn:match[@is-reading='true']/following-sibling::*,''),'^\*',''),'\s+',' ')
        return map {"before" := $before, "glyph" := $glyph, "after" := $after}
};

declare function annotation:parsedContextToString($parsed as map()) as xs:string {
    string-join((
        for $n in map:keys($parsed) order by index-of(("before", "glyph", "after"), $n)
        return 
            if ($n = "glyph")
            then    
                if (some $x in ($parsed("before"), $parsed("after")) satisfies contains($x, $parsed("glyph")))
                then concat(map:get($parsed, $n),'*') 
                else map:get($parsed, $n)
            else map:get($parsed, $n)
    ),'')
};

declare function annotation:renderContext($context as element(tei:seg)) (:as xs:string:) {
    let $glyph := $context/tei:g,
        $ana := fn:analyze-string(xs:string($context), xs:string($glyph), "i")
    let $content := 
        switch(count($ana/fn:match))
            case 0 return $context/normalize-space(.)
            case 1 return $context/normalize-space(.)
            default return 
                string-join((
                    for $n in $context/node() 
                    return 
                        if ($n/self::tei:g) 
                        then concat($n,'*') 
                        else $n
                ),'')
    return $content
};


declare %private function annotation:getUUID(){
    util:uuid()
};
