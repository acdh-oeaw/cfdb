xquery version "3.0";

module namespace tablet = "http://www.oeaw.ac.at/acdh/cuneidb/tablet";

import module namespace config="http://www.oeaw.ac.at/acdh/cuneidb/config" at "xmldb:exist:///db/apps/cuneidb/modules/config.xqm";
import module namespace surface="http://www.oeaw.ac.at/acdh/cuneidb/surface" at "xmldb:exist:///db/apps/cuneidb/modules/surface.xqm";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare variable $tablet:template-filepath := $config:app-root||"/tabletTpl.xml";
declare variable $tablet:template := doc($tablet:template-filepath);

declare variable $tablet:seed-xsl-filepath := $config:app-root||"/seed.xsl";
declare variable $tablet:seed-xsl := doc($tablet:seed-xsl-filepath);

(:~
 : stores a new tablet document (based on form data) by creating a collection 
 : inside of $config:tablets-root and storing the data in there.
 :
 : @param $tei the TEI file as an tei:TEI element
 : @return true or false (success or failure)
:)
declare function tablet:new($tei as element(tei:TEI)) as map() {
 	(: because of the Image Markup Tool being picky with 
 	: data which is not in the default namespace, we have to 
 	: do an identity transform in order to get rid of any 
 	: spurious namespace prefixes :)
    let $xsl := doc('rmNsPrefixes.xsl')
    let $tei-prefRmvd := transform:transform($tei,$xsl,())
    let $id := $tei/@xml:id
    let $create-collection := xmldb:create-collection($config:tablets-root,$id)
    let $collection-created := 
    	if ($create-collection)
    	then util:log-app("INFO",$config:app-name,"Created collection for new tablet "||$id)
    	else (util:log-app("INFO",$config:app-name,"An error occured. Could not create collection "||$id||" in "||$config:tablets-root),false())
    let $store-tei := 
        try {
            xmldb:store($config:tablets-root || "/" || $id ,
            			$id||".xml", 
            			$tei-prefRmvd)
        } catch * {
            util:log-app("INFO",$config:app-name,"An error occured. Could not store tablet "||$id||".")
        }
	let $setACL := 
	   if ($create-collection and $store-tei)
	   then (
	       sm:add-group-ace($create-collection, "cuneiformDB", true(), "rwx"),
	       sm:add-group-ace($store-tei, "cuneiformDB", true(), "rwx")
	   )
	   else ()
	let $returnVal := 
		if ($create-collection and $store-tei)
		then true()
		else false()
	
	let $msg := 
		if ($returnVal)
		then "Tablet has been created."
		else "An error occured storing the tablet."
	return 
		map {
			"outcome" := $returnVal,
			"message" := $msg
		} 
	
		 
};


(: by now every cfdb group member can do everything :)
declare function tablet:setACL($paths as xs:string+) {
    for $p in $paths
    return sm:add-group-ace($p, "cuneiformDB", true(), "rwx")
};




declare function tablet:get($id as xs:string) as element(tei:TEI)? {
    let $log := util:log-app("DEBUG", $config:app-name, "tablet:get("||$id||")")
    return collection($config:tablets-root)//tei:TEI[tei:sourceDoc][@xml:id = $id]
};


declare function tablet:update($id as xs:string, $data as element(tei:TEI)) as empty() {
    let $data := tablet:get($id),
        $filepath := base-uri($data),
        $filename := tokenize($filepath,'/'),
        $path := substring-before('/'||$filename,$filepath)
    return xmldb:store($filename,$path,$data)
};


declare function tablet:update-is-pending($tablet-id as xs:string, $uri as xs:string*) {
    tablet:update-is-pending($tablet-id, $uri, true())
};


declare function tablet:update-is-pending($tablet-id as xs:string, $uri as xs:string*, $is-pending as xs:boolean) {
    let $log := util:log-app("INFO",$config:app-name," tablet:update-is-pending() -- tablet-id = "||$tablet-id)
    let $tablet-updates := $config:pending-updates-doc//tablet[@id = $tablet-id]
    return
        if (count($uri) gt 0) then
            for $r in $uri  
                let $update-pending := $tablet-updates/surface[. = $r]
                return
                if ($is-pending) then
                    if (exists($update-pending))
                    then update replace $update-pending with <surface when="{current-dateTime()}">{$r}</surface> 
                    else 
                        if (exists($tablet-updates))
                        then update insert <surface when="{current-dateTime()}">{$r}</surface> into $tablet-updates
                        else update insert <tablet id="{$tablet-id}"><surface when="{current-dateTime()}">{$r}</surface></tablet> into $config:pending-updates-doc/updates
                else
                    if (exists($update-pending))
                    then update delete $update-pending
                    else update delete $tablet-updates
        else update delete $tablet-updates
};


declare function tablet:remove($id as xs:string) as empty() {
    let $data := tablet:get($id),
        $filepath := base-uri($data),
        $filename := tokenize($filepath,'/'),
        $path := substring-before('/'||$filename,$filepath)
    return xmldb:remove($path,$filename)
};

declare function  tablet:extractGlyphs($tablet as element(tei:TEI)) {
    let $tablet-id := $tablet/@xml:id
    let $imt2tei := transform:transform($tablet, doc('IMT2TEI.xsl'),())
    let $snippets := 
        for $zone in $imt2tei//tei:zone[@rendition="cuneiform"]
            let $glyph-id := $imt2tei//tei:g[@corresp = concat('#',$zone/@xml:id)]/@xml:id,
                $graphic := $zone/parent::tei:surface/tei:graphic,
                (: we work on a in-memory-nodeset, so we have to fetch the location from the database resource :)
                $img-filepath := util:collection-name(tablet:get($tablet-id))||"/"||replace($graphic/@url,'\\','/')
            return
                if (util:binary-doc-available($img-filepath))
                then
                    let $img-crop := image:crop(util:binary-doc($img-filepath),($zone/@ulx,$zone/@uly,xs:integer($zone/@lry)-xs:integer($zone/@uly),xs:integer($zone/@lrx)-xs:integer($zone/@ulx)),"image/jpeg"),
                        $img-collection := $config:data-root||"/_glyphs/",
                        $create-tablet-collection := 
                            if (exists(collection($img-collection||"/"||$tablet-id)))
                            then ()
                            else xmldb:create-collection($img-collection,$tablet-id) 
                    return xmldb:store($img-collection||"/"||$tablet-id,$glyph-id||".jpg",$img-crop) 
                else util:log-app("INFO",$config:app-name,"image at "||$img-filepath||" is not available")
    return $imt2tei
}; 

declare function tablet:list() as map()* {
    let $log := util:log-app("DEBUG", $config:app-name, "tablet:list()")    
    let $map :=  
        for $d in collection($config:tablets-root)//tei:TEI[tei:sourceDoc] 
        return 
        map{
            "id" 		:= $d/xs:string(@xml:id),
            "title" 	:= $d/tei:teiHeader/tei:fileDesc/tei:titleStmt/data(tei:title),
            "filename"	:= util:document-name($d),
           	"path"		:= util:collection-name($d)
        }
    let $log := util:log-app("DEBUG", $config:app-name, "tablet:list -- found "||count($map)||" tablets")
    return $map
};



(:~ 
 : Extracts a zone of an image (glyph) and stores it to the database.
 : @param $zone the zone to extract
 : @param $id the ID of the zone / glyph to extract
 : @return the path to the stored image
 :)
declare function tablet:extractGlyph($zone as element(tei:zone), $id as xs:string) as xs:string? {
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


declare function tablet:path($tablet-id as xs:string?) as xs:string? {
    let $tablet := tablet:get($tablet-id)
    return util:collection-name($tablet)
};


(:~
 : lists data in the tablet's collection, possibly filtering by one ore more mime-types.
 : @param $id the id of the tablet
 : @param $mime-type-filter sequence of mime-types to find (optional)
 : @return full db-paths for each resource 
~:)
declare function tablet:listResources($id as xs:string) as xs:anyURI* {
	tablet:listResources($id,())
};

declare function tablet:listResources($id as xs:string, $mime-type-filter as xs:string*) as xs:anyURI* {
    let $col := $config:tablets-root || "/" ||$id
    let $col-available := xmldb:collection-available($col)
    let $imgs :=
    	if (not($col-available))
    	then util:log-app("INFO",$config:app-name,"Collection "||$col||" not found.")
    	else
	    	for $x in xmldb:get-child-resources(xs:anyURI($col))
				let $dbpath := $col || "/" || $x
				let $mime-type := xmldb:get-mime-type($dbpath)
				return 
					switch (true())
						case (exists($mime-type-filter) and ($mime-type = $mime-type-filter)) return xs:anyURI($dbpath)
						case (not(exists($mime-type-filter))) return xs:anyURI($dbpath)
						default return ()
    return $imgs
};

declare function tablet:listSurfaces($tablet-id as xs:string) as element(tei:surface)*  {
    let $data := tablet:get($tablet-id)
    return $data/tei:sourceDoc/tei:surface
};

(:~
 : Updates the tablet TEI document the given surface document $surface is part of. 
 : 
 : @param $surface the TEI file of the surface
 : @return empty()
~:)
declare function tablet:reset($tablet-id) as empty() {
	let $log := util:log-app("DEBUG", $config:app-name, "tablet:reset("||$tablet-id||")")
	let $mainTEI := tablet:get($tablet-id)
	let $log := 
	   if ($mainTEI) 
	   then util:log-app("DEBUG", $config:app-name, "found tablet "||base-uri($mainTEI))
	   else util:log-app("ERROR", $config:app-name, "could not locate tablet for this surface file")
	let $surface-docs :=
	   for $s in tablet:listSurfaces($tablet-id) 
	       let $surface-doc-uri := util:collection-name($mainTEI)||"/"||replace($s/tei:graphic/@url,'\.jpg$','.xml')
	       let $surface-doc := doc($surface-doc-uri)
	       return 
	           if (exists($surface-doc))
	           then $surface-doc/tei:TEI
	           else util:log-app("ERROR", $config:app-name, "could not load surface document at "||$surface-doc-uri)
	
	let $log := util:log-app("DEBUG", $config:app-name, "found "||count($surface-docs)||" surfaces documents")
	let $log := util:log-app("DEBUG", $config:app-name, string-join($surface-docs!base-uri(.)))
	
	(: reset IDs of any newly inserted Annotations :)
	let $resetIDs := for $surface in $surface-docs return surface:resetIDs($surface)
	(: overwrite the glyphs in the tablet :)
    let $addGlyphs := 
        for $surface in $surface-docs 
        return tablet:resetGlyphs($mainTEI, $surface//tei:div[@type='imtAnnotation'])
	(: expand annotations with short cut notation, that is tei:p elements only containing the reading :)
	let $expand-shortcut-notation :=
        for $surface in $surface-docs return 	
        	   for $p in $surface//tei:div[@type='imtAnnotation']/tei:div/tei:p[not(contains(.,'reading:'))]
        	   let $auto-reading := 
        	       if (normalize-space($p) = $config:annotationtext-to-ignore)
        	       then ('',util:log-app("INFO", $config:app-name, "setting empty annotation instead of parsing text '"||$p||"'"))
        	       else (normalize-space(xs:string($p)),util:log-app("INFO", $config:app-name, "expanding shortcut annotation '"||$p||"'"))
        	   return 
        	       let $full-notation := 
        	           <p xml:space="preserve">&#10;{string-join((
                            "reading:  "||$auto-reading,
                            "context:  "||$auto-reading,
                            "sequence: ",
                            "note:     "
                        ),'&#10;')}&#10;</p>
        	       return update replace $p with $full-notation  
    let $unset-pending := tablet:update-is-pending($tablet-id, (), false())
    return ()
};



declare function tablet:mkG($properties as map()) as element(tei:g) {
	<g xmlns="http://www.tei-c.org/ns/1.0">{(
		attribute {"type"} {$properties("sign")},
		attribute {"xml:id"} {$properties("id")},
		attribute {"facs"} {"#graphic_"||$properties("id")},
(:		if ($properties("sequence") != '' or $properties("arrangement") != '') :)
(:		then :)
		       (: always make a reference to charProp for sequence, event if ther's no user value :)
		       attribute {"ana"} {concat('#',replace($properties("id"),'^glyph','charDecl'))},
(:		else (),:)
		$properties("reading")
	)}</g>
};

declare function tablet:mkGlyph($properties as map()) as element(tei:glyph) {
	<glyph xml:id="{replace($properties("id"),'^glyph','charDecl')}" xmlns="http://www.tei-c.org/ns/1.0">{
		for $p in "sequence" return
		    (: always make a charProp for sequence, even if there's no value, so that 
		    there is an input in the xforms :)
(:			if (map:get($properties, $p) != '') :)
(:			then :)
			    <charProp xmlns="http://www.tei-c.org/ns/1.0">
					<localName>{$p}</localName>
					<value>{map:get($properties,$p)}</value>
				</charProp>
(:			else ():)
	}</glyph>
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
declare function tablet:resetGlyphs($mainTEI as element(tei:TEI), $annotations as element(tei:div)*) as empty() {
	(: find out the url of the annotated image, we assume all annotations point to the same surface/graphic :)
	let $zone1ID := substring-after($annotations[1]/@corresp,'#')
	let $log := util:log-app("DEBUG", $config:app-name, "tablet:resetGlyphs() -- resetting glyph information in tablet "||$mainTEI/@xml:id||" in zone "||$zone1ID)
	let $sGraphic := root($annotations[1])//tei:zone[@xml:id = $zone1ID]/parent::*/tei:graphic
	(: retrieve the corresponding graphic in the tablet document :)
	let $tGraphic := $mainTEI//tei:graphic[@url = $sGraphic/@url]
	let $tZones := $tGraphic/parent::tei:surface/tei:zone
	let $tContexts := $mainTEI//tei:seg[@type='context'][@xml:id = $tZones/substring-after(@corresp,'#')]
	(: all zones pertaining to this zone are wiped :)
	let $log := util:log-app("DEBUG", $config:app-name, "deleting "||count($tContexts)||" contexts ")
	let $rmContexts := update delete $tContexts
	(: remove the current zones from the tablet document :)
	let $rmZones := update delete $tGraphic/parent::tei:surface/tei:zone
	return 
		for $a in $annotations
		    let $log := util:log-app("DEBUG", $config:app-name, "tablet:resetGlyphs() "||$a/@corresp)
			let $zoneID := substring-after($a/@corresp,'#'),
			    $aZone := root($a)//tei:zone[@xml:id = $zoneID]
			let $imgPath := tablet:extractGlyph($aZone, $zoneID),
			    $relImgPath := string-join(reverse(reverse(tokenize($imgPath,'/'))[position() le 2]),'/')
			let $properties := surface:parseAnnotation($a)
			(: if there is no user value for "context", just take the reading :)
			
			let $reading := $properties("reading"),
			    $context := if (not($properties("context")) or matches($properties("context"),'(^\s*$|^[X\s]+$)')) then $reading else $properties("context"),
				$id := $properties("id")

            let $log := 
                (util:log-app("DEBUG",$config:app-name, "context="||$context),
                util:log-app("DEBUG",$config:app-name, "reading="||$reading))
			
			(: a zone representing the context and the glyph in it :)
			let $cZone := 
			     <zone xmlns="http://www.tei-c.org/ns/1.0" corresp="#{replace($id,'^glyph','context')}"> 
			         <zone corresp="#{$id}"> 
			             {$aZone/(@ulx,@uly,@lrx,@lry)}
			             <graphic url="{$relImgPath}" xml:id="graphic_{$id}"/>
			         </zone>
			     </zone>
			     
			(::)			
			(: the 'transcription' and glyph information :)
			let $readingRegex := $reading(:replace($reading,'([\^\$\.\?\*\+\-])','\\\1'):)
			let $log := util:log-app("DEBUG",$config:app-name, $readingRegex)
			let $cSeg :=  
			    <seg type="context" xmlns="http://www.tei-c.org/ns/1.0" xml:id="{replace($id,'^glyph','context')}">{
		    		let $a := fn:analyze-string($context,$readingRegex||"\*?")
		    		return 
			        for $n in $a/*
			        return
			            if ($n/self::fn:non-match) 
			            then $n/text()
			            else 
			                if (count($a/fn:match) gt 1 and exists($a/fn:match[ends-with(.,'*')]))
			                then 
			                    if (ends-with($n,'*'))
			                    then tablet:mkG($properties)
			                    else $n/text()
			                else tablet:mkG($properties)
			    }</seg>
			
			let $log := util:log-app("DEBUG",$config:app-name, $cSeg)
			(: the glyph element in the teiHeader holding 'sequence' and 'arrangement' properties :)    
			let $glyph := tablet:mkGlyph($properties)
			
			return ( 
				(: insert the zone for this context into sourceDoc/surface :)
				update insert $cZone into $tGraphic/parent::tei:surface,
				(: remove current transcriptions for this context :)
				update delete $mainTEI//tei:seg[@type='context'][tei:g/@xml:id = $id],
				(: insert the transcription into the body :)
				update insert $cSeg into $mainTEI/tei:text/tei:body/tei:ab,
				(: insert a note into the back of the document :)
                update delete $mainTEI/tei:text/tei:back/tei:note[@target = concat('#',$properties('id'))],
                update insert <note xmlns="http://www.tei-c.org/ns/1.0" target="#{$properties('id')}">{$properties('note')}</note> into $mainTEI/tei:text/tei:back,
				let $charDecl := root($tGraphic)/tei:TEI/tei:teiHeader/tei:encodingDesc/tei:charDecl,
				    $tGlyph := update delete $charDecl/tei:glyph[@xml:id = $glyph/@xml:id]
					return update insert $glyph into $charDecl
			)
};





(:~
 : Updates the IMT TEI document for every surface in $tablet with the 
 : values in the $tablet file. 
~:)
declare function tablet:updateSurfaces($tablet-id as xs:string?) as empty() {
    let $log:= (util:log-app("INFO",$config:app-name,""),util:log-app("INFO",$config:app-name,"tablet:updateSurfaces("||$tablet-id||")"))
    let $tablet := tablet:get($tablet-id)
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
        
        let $log := for $x in ("$type","$reading","$context","$sequence","$arrangement","$note") return util:log-app("DEBUG",$config:app-name,concat($x," '",util:eval($x),"'"))
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

