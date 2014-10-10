xquery version "3.0";

(:~ This XQuery is called each time a facsmile TEI document 
 : is updated. It extracts the IMT annotations in it,
 : converts them into TEI markup 
 : updates the main TEI file with it.
 :)

module namespace trigger="http://exist-db.org/xquery/trigger";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

import module namespace tablet="http://www.oeaw.ac.at/acdh/cuneidb/tablet" at "xmldb:exist:///db/apps/cuneidb/modules/tablet.xqm";
import module namespace surface="http://www.oeaw.ac.at/acdh/cuneidb/surface" at "xmldb:exist:///db/apps/cuneidb/modules/surface.xqm";
import module namespace config = "http://www.oeaw.ac.at/acdh/cuneidb/config" at "xmldb:exist:///db/apps/cuneidb/modules/config.xqm";


(:~ 
 : Helper function that handles data retrieval for the document refered to by the trigger.
 : We potentially have to deal with binary docs here.
~:)
declare function local:get-data($uri as xs:anyURI) as document-node()? {
	if (util:binary-doc-available($uri)) 
	then ()
	else 
		if (doc-available($uri))
		then doc($uri)
		else ()
};


(:~ By default, the Image Markup Tool adds IDs like 'imtArea_0' to its 
 : zones and refers to them from the Annotation-divs via @corresp.
 : 
 : Here we update those IDs and IDRefs to be application-independent by replacing 
 : them with the @xml:id of the tei:TEI element, which is the tablet-id 
 : ('tablet_' being replaced by 'surface_') plus the filename of the IMT image.
 : 
 : Given the tablet 'tablet_YOS21209' and the image file 'NCBT 369 UE' a
 : zone-id of 'imtArea_0' becomes 'surface_YOS21209_NCBT369UE_0'.
 : 
 : As this function is called every time an IMT document is stored, we 
 : make sure that we only change those IDs that have been added by the IMT,
 : e.g. those that start with 'imtArea'.
~:)
declare function local:resetIDs($surface as element(tei:TEI)) as empty() {
	if ($surface//tei:zone/@xml:id[starts-with(.,'imtArea')])
	then
	   (: fetch the TEI document of the tablet this surface document is part of :)
	   let $tablet := collection(util:collection-name($surface))//tei:TEI[tei:sourceDoc], 
	       $tID := $tablet/xs:string(@xml:id)
	   return for $zone at $n in $surface//tei:zone[starts-with(@xml:id,'imtArea')]
	   let $zone-id := $zone/@xml:id,
	       $new-id := replace($tID,'^tablet_','glyph_')||"_"||$surface/@xml:id||"_"||substring-after($zone-id,'imtArea_')
        return
			(update value $surface//tei:div[@type='imtAnnotation'][@corresp = concat('#',$zone-id)]/@corresp with concat('#',$new-id),
			update value $zone-id with $new-id)
	else()
};


(:~ 
 : Extracts glyphs from the annotated images, stores them to the db and 
 : adds their properties to the tablet document. This is a complete build up
 : of the data for this surface: any existing glyphs are overwritten.
 : 
 : @param $mainTEI reference to the tablet
 : @param $annotations IMT annotation divs
 : @return empty 
 :)
declare function local:setGlyphs($mainTEI as element(tei:TEI), $annotations as element(tei:div)*) as empty() {
	(: find out the url of the annotated image, we assume all annotations point
	to the same surface/graphic :)
	let $zone1ID := substring-after($annotations[1]/@corresp,'#')
	let $sGraphic := root($annotations[1])//tei:zone[@xml:id = $zone1ID]/parent::*/tei:graphic
	(: retrieve the corresponding graphic in the tablet document :)
	let $tGraphic := $mainTEI//tei:graphic[@url = $sGraphic/@url]
	(: remove the current zones from the tablet document :)
	let $rmZones := update delete $tGraphic/parent::tei:surface/tei:zone 
	return 
		for $a in $annotations
			let $zoneID := substring-after($a/@corresp,'#'),
			    $aZone := root($a)//tei:zone[@xml:id = $zoneID]
			let $imgPath := local:extractGlyph($aZone, $zoneID),
			    $relImgPath := string-join(reverse(reverse(tokenize($imgPath,'/'))[position() le 2]),'/')
			let $properties := local:parseAnnotation($a)
			let $context := $properties("context"),
				$reading := $properties("reading"),
				$id := $properties("id")
			
			(: a zone representing the context and the glyph in it :)
			let $cZone := 
			     <zone xmlns="http://www.tei-c.org/ns/1.0" corresp="#{replace($id,'^glyph','context')}"> 
			         <zone corresp="#{$id}"> 
			             {$aZone/(@ulx,@uly,@lrx,@lry)}
			             <graphic url="{$relImgPath}" xml:id="graphic_{$id}"/>
			         </zone>
			     </zone>
			
			(: the 'transcription' and glyph information :)
			let $cSeg :=  
			    <seg type="context" xmlns="http://www.tei-c.org/ns/1.0" xml:id="{replace($id,'^glyph','context')}">{
		    		let $a := fn:analyze-string($context,$reading||"\*?")
		    		return 
			        for $n in $a/*
			        return
			            if ($n/self::fn:non-match) 
			            then $n/text()
			            else 
			                if (count($a/fn:match) gt 1 and exists($a/fn:match[ends-with(.,'*')]))
			                then 
			                    if (ends-with($n,'*'))
			                    then local:mkG($properties)
			                    else $n/text()
			                else local:mkG($properties)
			    }</seg>
			
			(: the glyph element in the teiHeader holding 'sequence' and 'arrangement' properties :)    
			let $glyph := local:mkGlyph($properties)
			
			return ( 
				(: insert the zone for this context into sourceDoc/surface :)
				update insert $cZone into $tGraphic/parent::tei:surface,
				(: remove current transcriptions for this context :)
				update delete $mainTEI//tei:seg[@type='context'][tei:g/@xml:id = $id],
				(: insert the transcription into the body :)
				update insert $cSeg into $mainTEI/tei:text/tei:body/tei:ab,
				(: insert a note into the back of the document :)
				if ($properties('note') = '') 
				then ()
				else update insert <note xmlns="http://www.tei-c.org/ns/1.0" target="#{$properties('id')}">{$properties('note')}</note> into $mainTEI/tei:text/tei:back,
				if (not($properties("sequence") != '' or $properties("arrangement") != '')) 
				then ()
				else
					let $charDecl := root($tGraphic)/tei:TEI/tei:teiHeader/tei:encodingDesc/tei:charDecl,
						$tGlyph := update delete $charDecl/tei:glyph[@xml:id = $glyph/@xml:id]
					return update insert $glyph into $charDecl
			)
};

(:~ 
 : Extracts a zone of an image (glyph) and stores it to the database.
 : @param $zone the zone to extract
 : @param $id the ID of the zone / glyph to extract
 : @return the path to the stored image
 :)
declare function local:extractGlyph($zone as element(tei:zone), $id as xs:string) as xs:string? {
	let $graphic := $zone/parent::*/tei:graphic
	return
	   switch(true())
	       case (not(exists($graphic))) return util:log-app("INFO",$config:app-name,"no element tei:graphic")
	       case (not(exists($graphic/@url))) return util:log-app("INFO",$config:app-name,"$graphic is missing @url attribute")
	       case (not(exists($zone/@ulx))) return util:log-app("INFO",$config:app-name,"$zone is missing @ulx attribute")
	       case (not(exists($zone/@uly))) return util:log-app("INFO",$config:app-name,"$zone is missing @uly attribute")
	       case (not(exists($zone/@lrx))) return util:log-app("INFO",$config:app-name,"$zone is missing @lrx attribute")
	       case (not(exists($zone/@lry))) return util:log-app("INFO",$config:app-name,"$zone is missing @lry attribute")
	       default return
	           let $collection := util:collection-name($zone)
	           let $img := image:crop(
	               util:binary-doc($collection||"/"||$graphic/@url),
	               ($zone/@ulx,
	                $zone/@uly,
	                xs:integer($zone/@lry)-xs:integer($zone/@uly),
     				xs:integer($zone/@lrx)-xs:integer($zone/@ulx)
     				),"image/jpeg")
               let $glyphsCol := if (xmldb:collection-available($collection||"/_glyphs")) 
								 then ()
								 else xmldb:create-collection($collection,"_glyphs")
               return xmldb:store($collection||"/_glyphs", $id||".jpg", $img)		
};

declare function local:mkG($properties as map()) as element(tei:g) {
	<g xmlns="http://www.tei-c.org/ns/1.0">{(
		attribute {"type"} {$properties("sign")},
		attribute {"xml:id"} {$properties("id")},
		attribute {"facs"} {"#graphic_"||$properties("id")},
		if ($properties("sequence") != '' or $properties("arrangement") != '') 
		then attribute {"ana"} {concat('#',replace($properties("id"),'^glyph','charDecl'))}  
		else (),
		$properties("reading")
	)}</g>
};

declare function local:mkGlyph($properties as map()) as element(tei:glyph) {
	<glyph xml:id="{replace($properties("id"),'^glyph','charDecl')}" xmlns="http://www.tei-c.org/ns/1.0">{
		for $p in ("sequence","arrangement") return
			if (map:get($properties, $p) != '') 
			then <charProp xmlns="http://www.tei-c.org/ns/1.0">
					<localName>{$p}</localName>
					<value>{map:get($properties,$p)}</value>
				</charProp>
			else ()
	}</glyph>
};

declare function local:parseAnnotation($annotation as element(tei:div)) as map() {
	let $sign := map:entry("sign",$annotation/xs:string(tei:head)),
		$id := map:entry("id",substring-after($annotation/@corresp,'#'))
	let $lines := tokenize($annotation/tei:div/tei:p/text(),'\s*\n\s*')
	let $fields := 
			for $l in $lines 
				let $field := normalize-space(substring-before($l,':')),
					$value := normalize-space(substring-after($l,':'))
				return 
					if ($field !='')
					then map:entry($field,$value)
					else ()
	return map:new(($sign,$id,$fields)) 
};

declare function local:updateTablet($surface as element(tei:TEI)) as empty() {
	(: find the tablet this surface document belongs to :)
	let $mainTEI := collection(util:collection-name($surface))//tei:TEI[tei:sourceDoc]
	(: reset IDs of any newly inserted Annotations :)
	let $resetIDs := local:resetIDs($surface)
	(: overwrite the glyphs in the tablet :)
	let $addGlyphs := local:setGlyphs($mainTEI, $surface//tei:div[@type='imtAnnotation'])
	return ()
};

(:~
 : Updates the IMT TEI document for every surface in $tablet with the 
 : values in the $tablet file. 
~:)
declare function local:updateSurfaces($tablet as element(tei:TEI)) as empty() {
    let $log:= (util:log-app("INFO",$config:app-name,""),util:log-app("INFO",$config:app-name,"local:updateSurfaces("||base-uri($tablet)||")"))
    return
    for $c at $pos in $tablet//tei:seg[@type = 'context']
        let $count:= util:log-app("INFO",$config:app-name,"context "||$pos||" of "||count($tablet//tei:seg[@type = 'context'])||" - "||$c/@xml:id)
        (: we assume one context for each glyph :)
        let $unique-g := if (count($c/tei:g) gt 1)
                         then (util:log-app("INFO",$config:app-name,"beware: more than one tei:g in context "||$c/@xml:id),false())
                         else true()
        let $g := $c/tei:g[1],
            $gID := $c/tei:g[1]/@xml:id
        
        let $type := $g/@type,
            $reading := $g/text(),
            $context := $c/string-join((
                            for $n in node() return 
                                if ($n/self::tei:g) 
                                then 
                                    if (contains($c/text(),$n/text())) 
                                    then $n/text()||"*"
                                    else $n/text() 
                                else 
                                    if ($n/self::text()) 
                                    then $n 
                                    else ()
                        ),""),
            $sequence := root($c)//tei:glyph[@xml:id = substring-after($g/@ana,'#')]/tei:charProp[tei:localName = "sequence"]/tei:value,
            $arrangement := root($c)//tei:glyph[@xml:id = substring-after($g/@ana,'#')]/tei:charProp[tei:localName = "arrangement"]/tei:value,
            $note := root($c)//tei:note[@target = $gID]
        
        let $log := for $x in ("$type","$reading","$context","$sequence","$arrangement","$note") return util:log-app("INFO",$config:app-name,concat($x," '",util:eval($x),"'"))
        let $sDiv := collection(util:collection-name($tablet))//tei:div[@corresp = concat('#',$gID)]
        let $log := util:log-app("INFO",$config:app-name,exists($sDiv))
        let $newAn :=
            <div type="imtAnnotation" corresp="{concat('#',$gID)}" xmlns="http://www.tei-c.org/ns/1.0">
                <head>{xs:string($type)}</head>
                <div><p xml:space="preserve">&#10;{string-join((
                    "reading:  "||xs:string($reading),
                    "context:  "||normalize-space(xs:string($context)),
                    "sequence: "||xs:string($sequence),
                    "note:     "||xs:string($note)
                ),'&#10;')}&#10;</p></div>
            </div>
        return update replace $sDiv with $newAn
};


(:~ "main" functions that are called by the trigger. :)
declare function trigger:after-update-document($uri as xs:anyURI) {
    let $log := util:log-app("INFO",$config:app-name,"trigger:after-update-document("||$uri||")")
	let $data := local:get-data($uri),
		$type := if (exists($data/tei:TEI/tei:sourceDoc)) then "tablet"
				 else if (exists($data//tei:div[@xml:id = 'imtImageAnnotations'])) then "surface"
				 else (util:log-app("INFO",$config:app-name,"$type could not be determined."))
	let $update := 
		if ($type = "surface") then 
			local:updateTablet($data/tei:TEI) else  
		if ($type = "tablet") then 
			local:updateSurfaces($data/tei:TEI)
		else ()
	return ()
};

(:declare function trigger:before-delete-document($uri as xs:anyURI) {
    let $log := util:log-app("INFO",$config:app-name,"trigger:before-delete-document("||$uri||")")
	let $data := local:get-data($uri),
		$type := if (exists($data/tei:TEI/tei:sourceDoc)) then "tablet"
				 else if (exists($data//tei:div[@xml:id = 'imtImageAnnotations'])) then "surface"
				 else (util:log-app("INFO",$config:app-name,"$type could not be determined."))
	let $update := 
	   if ($type = "surface") then ()(\:surface:remove($uri):\)   
	   else ()
	return ()
};:)