xquery version "3.0";

module namespace surface = "http://www.oeaw.ac.at/acdh/cuneidb/surface";

import module namespace config = "http://www.oeaw.ac.at/acdh/cuneidb/config" at "xmldb:exist:///db/apps/cuneidb/modules/config.xqm";
import module namespace tablet = "http://www.oeaw.ac.at/acdh/cuneidb/tablet" at "xmldb:exist:///db/apps/cuneidb/modules/tablet.xqm";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare variable $surface:template-filepath := $config:app-root||"/surfaceTpl.xml";
declare variable $surface:template := doc($surface:template-filepath);

declare variable $surface:seed-xsl-filepath := $template:seed-xsl-filepath;
declare variable $surface:seed-xsl := doc($tablet:seed-xsl-filepath);

(:~ Each tablet constists of a "main" TEI document holding metadata in its teiHeader and a 
 : tei:sourceDoc element containing a series of tei:surface elements with 
 : tei:graphics referencing Images that are annotated with the Image Markup Tool. 
 : 
 : As the Image Markup Tool can only edit TEI documents with one surface, each image of a 
 : tablet has to be represented by its own TEI document. This function generates such a  
 : "surface" TEI document and adds a corresponding tei:surface element to the "main" 
 : TEI document that represents the tablet.
 :
~:)
declare function surface:new($path-to-img as xs:anyURI) {
    let $log := util:log("INFO",$path-to-img)
    let $filename := tokenize($path-to-img,'/')[last()], 
        $suffix := "."||tokenize($filename,'\.')[last()],
        $collection := substring-before($path-to-img,$filename),
        $height := image:get-height(util:binary-doc($path-to-img)),
        $width := image:get-width(util:binary-doc($path-to-img))
    
    let $parameters := 
        <parameters>
            <param name="filename" value="{$filename}"/>
            <param name="title" value="{xmldb:decode(translate(substring-before($filename,$suffix),'_',' '))}"/>
            <param name="height" value="{$height}px"/>
            <param name="width" value="{$width}px"/>
            <param name="type" value="surface"/>
        </parameters>
     
    let $IMT-file := transform:transform($surface:template, $surface:seed-xsl, $parameters)/self::tei:TEI
    
    let $main-TEI := collection($collection)//tei:TEI[tei:sourceDoc],
    	$IMT-graphic := $IMT-file/tei:facsimile[@xml:id = 'imtAnnotatedImage']/tei:surface/tei:graphic, 
    	$surface := if (not(exists($main-TEI/tei:sourceDoc/tei:surface[tei:graphic/@url = $IMT-graphic/@url])))
    				then update insert <surface xmlns="http://www.tei-c.org/ns/1.0">{$IMT-graphic}</surface> into $main-TEI/tei:sourceDoc
    				else ()
    
    return 
        (:switch(true())
            case (not(util:binary-doc-available($path-to-img))) return util:log("INFO",$path-to-img||" is not available")
            case (doc-available($collection||"/"||replace($filename,'\..+$','.xml'))) return util:log("INFO",$path-to-img||" file already exists")
            default return :)
         xmldb:store($collection, substring-before($filename,$suffix)||".xml", $IMT-file)
};



(:~ 
 : Removes the surface TEI document that represents the graphic at $path-to-img and
 : removes also its corresponding tei:surface element from the "tablet" TEI document. 
 :)
declare function surface:remove($path as xs:anyURI) {
    let $mime-type := xmldb:get-mime-type($path)
    let $filename := tokenize($path,'/')[last()],
        $collection := substring-before($path,"/"||$filename)
    let $IMT-filename :=
        switch($mime-type)
            case ("application/xml") return $filename
            case (contains($mime-type,"image")) return string-join(tokenize($filename,'\.') except last(),'.')||".xml"
            default return ()
    
    
    
    let $mainTEI := collection($collection)//tei:TEI[tei:sourceDoc],
    	$surfaceInTablet := $mainTEI//tei:surface[tei:graphic/@url = $filename]
    let $log := for $x in ("$filename","$IMT-filename","$surfaceInTablet","exists($mainTEI)") return util:log("INFO",$x||" "||util:eval($x))

    (: remove glyph and glyph images :)
    let $rmGlyphs := 
    	for $g in $surfaceInTablet//tei:grapic  
    	   let $contexts := $mainTEI//tei:seg[@type='context'][tei:g/@facs = $g/@url],
    	       $glyphElts := $mainTEI//tei:glyph[@xml:id = $contexts//tei:g/concat('#',@xml:id)]
    	   return (
    	       update delete $glyphElts,
    	       update delete $contexts,
    	       if ($g/@url != '')
    	       then xmldb:remove($collection||"/"||$g/@url)
    	       else ()
    	   )
    (: remove tei:surface in the "main" tablet document :)
    let $rmSurface := update delete $surfaceInTablet
    (: remove the "surface" TEI document :)
    let $rmTEI := if ($IMT-filename != $filename) then xmldb:remove($collection,$IMT-filename) else ()
    
    return ()
};
