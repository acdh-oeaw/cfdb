xquery version "3.0";

module namespace tablet = "http://www.oeaw.ac.at/acdh/cuneidb/tablet";

import module namespace config="http://www.oeaw.ac.at/acdh/cuneidb/config" at "xmldb:exist:///db/apps/cuneidb/modules/config.xqm";

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
    	then util:log("INFO","Created collection for new tablet "||$id)
    	else (util:log("INFO","An error occured. Could not create collection "||$id||" in "||$config:tablets-root),false())
    let $store-tei := 
        try {
            xmldb:store($config:tablets-root || "/" || $id ,
            			$id||".xml", 
            			$tei-prefRmvd)
        } catch * {
            util:log("INFO","An error occured. Could not store tablet "||$id||".")
        }
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




declare function tablet:get($id as xs:string) as element(tei:TEI)? {
    collection($config:tablets-root)//tei:TEI[tei:sourceDoc][@xml:id = $id]
};


declare function tablet:update($id as xs:string, $data as element(tei:TEI)) as empty() {
    let $data := tablet:get($id),
        $filepath := base-uri($data),
        $filename := tokenize($filepath,'/'),
        $path := substring-before('/'||$filename,$filepath)
    return xmldb:store($filename,$path,$data)
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
                else util:log("INFO","image at "||$img-filepath||" is not available")
    return $imt2tei
}; 

declare function tablet:list() as map()* {
    for $d in collection($config:tablets-root)//tei:TEI[tei:sourceDoc] 
    return 
    map{
        "id" 		:= $d/xs:string(@xml:id),
        "title" 	:= $d/tei:teiHeader/tei:fileDesc/tei:titleStmt/data(tei:title),
        "filename"	:= util:document-name($d),
       	"path"		:= util:collection-name($d)
    }
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
    	then util:log("INFO","Collection "||$col||" not found.")
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