xquery version "3.0";

module namespace tablet = "http://www.oeaw.ac.at/acdh/cuneidb/tablet";

import module namespace config="http://www.oeaw.ac.at/acdh/cuneidb/config" at "xmldb:exist:///db/apps/cuneidb/modules/config.xqm";
import module namespace surface="http://www.oeaw.ac.at/acdh/cuneidb/surface" at "xmldb:exist:///db/apps/cuneidb/modules/surface.xqm";
import module namespace annotation = "http://www.oeaw.ac.at/acdb/cuneidb/annotations" at "xmldb:exist:///db/apps/cuneidb/modules/annotations.xqm";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare variable $tablet:template-filepath := $config:app-root||"/tabletTpl.xml";
declare variable $tablet:template := doc($tablet:template-filepath);

declare variable $tablet:seed-xsl-filepath := $config:app-root||"/seed.xsl";
declare variable $tablet:seed-xsl := doc($tablet:seed-xsl-filepath);

(:~
 : stores a new tablet document (based on form data) by creating a collection 
 : inside of $config:tablets-root and storing the data in there.
 : TODO rename result map key name "outcome" to "status" () 
 : 
 : @param $tei the TEI file as an tei:TEI element
 : @return a map containing the mandatory fields "outcome" and "msg"
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
		map {"outcome" := $returnVal, "message" := $msg}	 
};


(: sets the access control list for the given paths
 : NB by now every cfdb group member can do everything, this will be subject to change
 : @param $paths one or more strings containing db-paths
 :)
declare function tablet:setACL($paths as xs:string+) {
    for $p in $paths
    return sm:add-group-ace($p, "cuneiformDB", true(), "rwx")
};


(:~ retrieves the tablet identified by its id 
 : @param $id the tablet's id 
 : @return the tablet's tei:TEI element 
 :)
declare function tablet:get($id as xs:string) as element(tei:TEI)? {
    let $log := util:log-app("DEBUG", $config:app-name, "tablet:get("||$id||")")
    return collection($config:tablets-root)//tei:TEI[tei:sourceDoc][@xml:id = $id]
};


(:~ retrieves the id of the given tablet
 : @param $tablet the tablet as a tei:TEI element
 : @return a string with the tablet's id 
 :)
declare function tablet:id($tablet as element(tei:TEI)) as xs:string {
    $tablet/xs:string(@xml:id)
};



(:~ removes all data of the given tablet
 : @param $tablet the tablet as a tei:TEI element
 : @return empty sequence
 :)
declare function tablet:remove($tablet as element(tei:TEI)) as empty() {
    (:let $data := tablet:get($id),
        $filepath := base-uri($data),
        $filename := tokenize($filepath,'/'),
        $path := substring-before('/'||$filename,$filepath)
    return xmldb:remove($path,$filename):)
    xmldb:remove(tablet:path($tablet))
};


(:~ lists all tablets in the database 
 : TODO to be moved in a separate cfdb-module
 : @return zero or more maps with the mandadory fields "id", "title", "filename" and "path"
 :)
declare function tablet:list() as map()* {
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


(:~ returns the db base path containing all tablet data (source, img and derivates)
 : @param $tablet the tablet as a tei:TEI element
 : @return db-path as a string 
 :)
declare function tablet:path($tablet as element(tei:TEI)) as xs:string? {
    util:collection-name($tablet)
};


(:~
 : lists data in the tablet's collection, possibly filtering by one ore more mime-types.
 : @param $tablet the tablet as a tei:TEI element
 : @param $mime-type-filter sequence of mime-types to find (optional)
 : @return full db-paths for each resource 
~:)
declare function tablet:listResources($tablet as element(tei:TEI)) as xs:anyURI* {
	tablet:listResources($id,())
};

(:~
 : lists data in the tablet's collection, possibly filtering by one ore more mime-types.
 : @param $tablet the tablet as a tei:TEI element
 : @param $mime-type-filter sequence of mime-types to find (optional)
 : @return full db-paths for each resource 
~:)
declare function tablet:listResources($tablet as element(tei:TEI), $mime-type-filter as xs:string*) as xs:anyURI* {
    let $col := tablet:path($tablet)
    let $col-available := xmldb:collection-available($col)
    let $resources :=
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
    return $resources
};

(:~ returns all surfaces in the given tablet
 : @param $tablet the tablet as a tei:TEI element 
 : @return zero or more tei:surface elements
 :)
declare function tablet:listSurfaces($tablet as element(tei:TEI)) as element(tei:surface)*  {
    $tablet/tei:sourceDoc/tei:surface
};

