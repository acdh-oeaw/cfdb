xquery version "3.0";

declare namespace api = "http://acdh.oeaw.ac.at/cuneidb/api";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

import module namespace config="http://www.oeaw.ac.at/acdh/cuneidb/config" at "xmldb:exist:///db/apps/cuneidb/modules/config.xqm";

import module namespace tablet = "http://www.oeaw.ac.at/acdh/cuneidb/tablet" at "xmldb:exist:///db/apps/cuneidb/modules/tablet.xqm";
import module namespace surface = "http://www.oeaw.ac.at/acdh/cuneidb/surface" at "xmldb:exist:///db/apps/cuneidb/modules/surface.xqm";

(:~ 
 : This XQuery discovers uploaded image files in a tablet collection, 
 : creates one "surface" TEI document for each new one (which are to edited 
 : by the Image Markup Tool) and updates the tablet TEI document. 
 :)

declare variable $data external;

let $tablet := util:parse($data)/selectedTablet
let $id := $tablet/id
let $col := $tablet/xs:string(path)


return
	switch (true())
		case ($id = "" or not($id)) return 
			<selectedTablet xmlns="">
				{$tablet/(* except msg)}
				<msg>$id is empty</msg>
			</selectedTablet>
		
		case ($col = "" or not($col)) return 
			<selectedTablet xmlns="">
				{$tablet/(* except msg)}
				<msg>$col is empty</msg>
			</selectedTablet>
		
		default return
			let $imgs := tablet:listResources($id,("image/jpg","image/jpeg","IMAGE/JPEG","IMAGE/JPG"))
			let $log := util:log-app("INFO",$config:app-name,string-join($imgs,'; '))
			let $newSurfaces := 
				for $i in $imgs return 
					if (doc-available(replace($i,'(jpg|jpeg|JPG|JPEG)$','xml')))
					then ()
					else surface:new($i) 
					
			let $surfaces := tablet:listSurfaces($id)
			
			return			
				<selectedTablet xmlns="">
					{$tablet/(* except msg)}
					<msg>{
						switch(true())
							case count($surfaces) = 0 return "no images found"
							case count($newSurfaces) = 0 return "no new images found"
							default return count($newSurfaces)||" images loaded"
					}</msg>
				</selectedTablet>