xquery version "3.0";

module namespace archive = "@app.uri@/archive";

declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace http="http://expath.org/ns/http-client";
declare namespace dc="http://purl.org/dc/elements/1.1/";
declare namespace dcterms="http://purl.org/dc/terms/"; 

import module namespace config = "@app.uri@/config" at "xmldb:exist:///db/apps/@app.name@/modules/config.xqm";
import module namespace cfdb = "@app.uri@/db" at "xmldb:exist:///db/apps/@app.name@/modules/cfdb.xqm";
import module namespace tablet = "@app.uri@/tablet" at "xmldb:exist:///db/apps/@app.name@/modules/tablet.xqm";

(:~ The cfdb repository contains snapshots of the database that have been created by archive:create().
 : These contain only TEI files and cropped sign images along some metadata. These archives are world-readable
 : and can be fetched by a cfdb instance running in "public mode". 
 :)
declare variable $archive:repo-collection-name := "archive";
declare variable $archive:repo-parent-collection := $config:data-root;
declare variable $archive:repo-path := $archive:repo-parent-collection||"/"||$archive:repo-collection-name;

declare variable $archive:entry-filter := function($path as xs:string, $data-type as xs:string, $param as item()*) as xs:boolean{ if (ends-with($path, "dc.xml")) then true() else false() };
declare variable $archive:entry-data := function($path as xs:string, $data-type as xs:string, $data as item()?, $param as item()*) {$data};

declare function archive:create($version as xs:string) as element(cfdb:archive)? {
    archive:create($version, ())
};

(:~ archive:create creates a snipshot (archive) of the current state of the instance's data 
 : and places it inside the instance's public repository.
 :)
declare function archive:create($version as xs:string, $pid as xs:string?) as element() {
    if ($config:isPublicInstance eq true()) then <error>Cannot create an archive from public instance.</error>
    else if (exists(collection($archive:repo-path)//cfdb:archive[@version = $version])) then <error>Version {$version} already exists.</error>
    else if (not($version castable as xs:integer and xs:integer($version) gt 0)) then <error>Version must be an integer greater than 0.</error>
    else if (xs:integer($version) lt max(archive:list()/xs:integer(@version))) then <error>Version must be greater than the highest previous version number (i.e. {max(archive:list()/xs:integer(@version))}).</error>
    else
        let $all-tablets := cfdb:tablets()
        let $mime-types := ("application/xml", "image/png")
        let $tablets-data := for $t in $all-tablets return tablet:listResources($t, $mime-types),
            $tablets-data-paths := $tablets-data//resource/xs:anyURI(@path),
            $etc-data-paths := cfdb:ls($config:data-root||"/etc")//resource/xs:anyURI(@path) 
        let $filename := $config:app-name||"_"||$version||"SNAPSHOT_"||format-dateTime(current-dateTime(),'[Y0000][M00][D00]-[H00][m00][s00]')
        let $md := 
            <cfdb:archive version="{$version}">
                <dc:title>cfdb archive {$version}</dc:title>
                <dc:identifier>{$filename}</dc:identifier>
                <dcterms:URL>{($pid, config:get("public-url")||"/archive/"||$version)[1]}</dcterms:URL>                
                <dc:creator>{xmldb:get-current-user()}</dc:creator>
                <dcterms:issued>{current-dateTime()}</dcterms:issued>
                <dc:publisher>{config:get("publisher")}</dc:publisher>
                <dcterms:extent>{count($all-tablets//tei:g)} annotated signs, {count($all-tablets)} tablets, {count(($tablets-data-paths, $etc-data-paths))} files</dcterms:extent>
                <dcterms:license>{config:get("license")}</dcterms:license>
                <dcterms:source>{$config:UUID}</dcterms:source>
                <dc:description>This archive contains a snapshot of the data in the "{$config:app-name}" corpus at the time of its creation.</dc:description>
                <dc:tableOfContents>For each tablet (under "tablets") cropped images (png files) and metadata, including image annotations (as TEI files), are provided. Additional data in "etc": lists of places, persons, archives and terms as well as standard sign lists and standard sign images ("stdSigs/stdSigns.xml").</dc:tableOfContents>
            </cfdb:archive>
        let $md-entry := <entry name="dc.xml">{$md}</entry>
        let $zip-data-content := ($md-entry, $tablets-data-paths, $etc-data-paths)
        
        let $zip := compression:zip($zip-data-content, true(), $config:data-root)
        let $create-repo-if-not-exists := 
            if (xmldb:collection-available($archive:repo-path)) 
            then () 
            else 
                (xmldb:create-collection($archive:repo-parent-collection, $archive:repo-collection-name),
                sm:chgrp(xs:anyURI($archive:repo-path), "cfdbEditors"),
                sm:chmod(xs:anyURI($archive:repo-path), "rwxrwxr-x"))
        let $store := 
            try {
                (xmldb:store($archive:repo-path, $filename||".zip", $zip, "application/zip"), 
                xmldb:store($archive:repo-path, $filename||".xml", $md))
            } catch * {
                <error>An error occured storing the snapshot. ({$err:code} , {$err:description}, {$err:value})</error>
            }
        let $set-resource-permissions :=
            try {
                (sm:chgrp(xs:anyURI($archive:repo-path||"/"||$filename||".zip"), "cfdbEditors"),
                sm:chmod(xs:anyURI($archive:repo-path||"/"||$filename||".zip"), "rwxrwxr-x"),
                sm:chgrp(xs:anyURI($archive:repo-path||"/"||$filename||".xml"), "cfdbEditors"),
                sm:chmod(xs:anyURI($archive:repo-path||"/"||$filename||".xml"), "rwxrwxr-x"))
            } catch * {
                let $rm-archive := archive:remove($md/dc:identifier)
                return <error>An error occured setting resource permissions on newly created snapshot. Snapshot has not been created. ({$err:code} , {$err:description}, {$err:value})</error>
            }
        return  
            if ($store instance of element(error)) then $store
            else if ($set-resource-permissions instance of element(error)) then $set-resource-permissions
            else doc($store[ends-with(., ".xml")])/cfdb:archive 
};

(:~ The function archive:get-metadata returns full metadata about the snapshot specified by $id. 
 : It contains the original metdata created at the time of creation but also a formatted version for it 
 : to be displayed, including an estimate size in the database.   
 :)
declare function archive:get-extra-metadata($id-or-element) as element() {
    let $arg-type := typeswitch ($id-or-element) 
                        case element(cfdb:archive) return "stored-md"
                        case xs:string return "id"
                        default return ()
    return
        if (not($arg-type))
        then <error>parameter 1 of archive:get-metadata has wrong type: must be a snapshot ID (xs:string) or an element(cfdb:archive)</error>
        else 
            let $stored-md := if ($arg-type = "stored-md") then $id-or-element else collection($archive:repo-path)//cfdb:archive[dc:identifier = $id-or-element],
                $id := if ($arg-type = "id") then $id-or-element else $id-or-element/dc:identifier/data(.)
            return 
                if ($id = "") then <error>archive:get-metadata() $id is empty</error> else 
                if (not($stored-md)) then <error>archive:get-metadata() $stored-md is empty</error> else 
                let $md-filename := util:document-name($stored-md),
                    $zip-filename := replace($md-filename,"xml", "zip"),
                    $zip-available := util:binary-doc-available($archive:repo-path||"/"||$zip-filename),
                    $size := if ($zip-available) then xmldb:size($archive:repo-path, $zip-filename) else (),
                    $size-formatted := if ($zip-available) then round-half-to-even($size div 1024 div 1024, 2)||" MB" else (),
                    $date-formatted := format-dateTime($stored-md//dcterms:issued, "[D00]/[M00]/[Y0000] [H00]:[m00]")
                return 
                <archive xmlns="@app.uri@/db">
                    {($stored-md/@*, $stored-md/*)}
                    <extra>
                        <md-filename>{$md-filename}</md-filename>
                        <md-url>archive/{$md-filename}</md-url>
                        <zip-filename>{$zip-filename}</zip-filename>
                        <zip-available>{$zip-available}</zip-available>
                        <zip-url>archive/{$zip-filename}</zip-url>
                        <size>{$size}</size>
                        <size-formatted>{$size-formatted}</size-formatted>
                        <date-formatted>{$date-formatted}</date-formatted>
                        <removable>{xmldb:get-current-user() = $config:editors}</removable>
                    </extra>
                </archive>
};


(:~ This function returns a list of archive snapshots
 :)
declare function archive:list() as element(cfdb:archive)* {
    archive:get(())
};


(:~ The function archive:get retrieves the snaphot indicated by $id or lists all 
 : snapshots if there is no $id given. 
 :)
declare function archive:get($id as xs:string?) as element(cfdb:archive)* {
    if (exists($id))
    then collection($archive:repo-path)//cfdb:archive[dc:identifier = $id]
    else collection($archive:repo-path)//cfdb:archive
};

declare function archive:get-by-version($version) as element(cfdb:archive)* {
    collection($archive:repo-path)//cfdb:archive[@version = $version]
};

(:~ Removes the archive of a snapshot as well as the unpacked files.  
 :)
declare function archive:remove($identifier) {
    let $remove := 
        try {(
            if (doc-available($archive:repo-path||"/"||$identifier||".xml"))
            then (xmldb:remove($archive:repo-path, $identifier||".xml"))
            else (),
            if (util:binary-doc-available($archive:repo-path||"/"||$identifier||".zip"))
            then (xmldb:remove($archive:repo-path, $identifier||".zip"))
            else ()
        )} catch * {
            <error>An error occured. Could not remove snapshot {$identifier}. ({$err:code} , {$err:description}, {$err:value})</error>
        } 
    return $remove 
};

(:~ Removes the artefacts of a unpacked snapshot without removing the archive itself.
 :)
declare function archive:remove-artefacts($identifier) {
    let $remove := 
        try {
            if (xmldb:collection-available($archive:repo-path||"/"||$identifier))
            then (xmldb:remove($archive:repo-path||"/"||$identifier))
            else ()
        } catch * {
            <error>An error occured. Could not remove artefacts of snapshot {$identifier}. ({$err:code} , {$err:description}, {$err:value})</error>
        } 
    return $remove 
};

(: Stores a user-provided snapshot in the database :)
declare function archive:import($filename as xs:string, $archive as item()) {
    let $entry-filter := function($path as xs:string, $data-type as xs:string, $param as item()?) as xs:boolean {
            (: only export dublin core metadata entry  :)
            $path eq "dc.xml" 
        },
        $entry-data := function($path as xs:string, $data-type as xs:string, $data as item()*, $param as item()*) as document-node() {
            document { $data }
        }
    let $store-archive := try { xmldb:store($archive:repo-path, $filename, $archive, "application/zip") } catch * { <error>Could not store snapshot under {$archive:repo-path}/{$filename}. ({$err:code} , {$err:description}, {$err:value})</error> }
    let $md := if (not($store-archive instance of element(error))) then try { compression:unzip( $archive, $entry-filter, (), $entry-data, ()) } catch * { <error>Could not uncompress archive. ({$err:code} , {$err:description}, {$err:value})</error> } else ()
    let $identifier := $md//dc:identifier[1]/xs:string(.)
    let $store-md:= if ($identifier != "" and not($store-archive instance of element(error))) then try { xmldb:store($archive:repo-path, $identifier||".xml", $md, "application/xml") } catch * { <error>Could not store metadata entry under {$archive:repo-path}/{$identifier}.xml. ({$err:code} , {$err:description}, {$err:value})</error> } else <error>Invalid snapshot metadata: No dc:identifier found.</error>
    let $rename := if (not($store-md instance of element(error)) and $identifier != "") then try { xmldb:rename($archive:repo-path, $filename, $identifier||".zip") } catch * {<error>Could not rename {$filename} to {$identifier}.zip. ({$err:code} , {$err:description}, {$err:value})</error>}else ()
    return 
        if ($md instance of element(error)) then $md else 
        if ($store-archive instance of element(error)) then $store-archive else
        if ($store-md instance of element(error)) then $store-md else 
        if ($rename instance of element(error)) then $rename else $md
};

declare function archive:check-deployment-sanity() as map()? {
    let $id := config:get("deployed-snapshot")
    return archive:check-deployment-sanity($id)
};

declare function archive:check-deployment-sanity($id as xs:string) as map()? {
    let $snapshot := archive:get($id) 
    return
        if (exists($snapshot))
        then
            let $snapshot-path := ($archive:repo-path||"/"||$id)
            let $snapshot-col-available := if (xmldb:collection-available($snapshot-path)) then () else "Snapshot collection is not found.",
                $etc-col-exists := if (xmldb:collection-available($snapshot-path||"/etc")) then () else "Collection /etc is missing.",
                $tablets-col-exists := if (xmldb:collection-available($snapshot-path||"/tablets")) then () else "Colection /tablets is missing."
            let $errors := ($snapshot-col-available, $etc-col-exists, $tablets-col-exists)[. instance of xs:string]
            return
                if (not(exists($errors)))
                then map {"status" := "ok"}
                else map {"status" := "error", "msg" := string-join($errors, " ")}
        else ()
};

declare %private function archive:create-collection-recursively($collection, $paths as xs:string*) {
    let $create := 
        if (count($paths) ge 1)
        then 
            if (xmldb:collection-available($collection||"/"||$paths[1])) 
            then () 
            else xmldb:create-collection($collection, $paths[1])
        else ()
    return 
        if (count($paths) gt 1)
        then archive:create-collection-recursively($collection||"/"||$paths[1], subsequence($paths, 2))
        else ()
};

declare function archive:deploy($id as xs:string, $removeDeployedSnaphot as xs:boolean) {
    let $current := config:get("deployed-snapshot")
    let $snapshot := archive:get($id),
        $snapshot-collection := $archive:repo-path||"/"||$id
    let $entry-filter := function($path as xs:string, $data-type as xs:string, $param as item()?) as xs:boolean {
            (: extract everything :)
            true()
        },
        $entry-data := function($path as xs:string, $data-type as xs:string, $data as item()*, $param as item()*){
            let $folders := if (contains($path,"/")) then subsequence(tokenize($path, "/"), 1, count(tokenize($path, "/"))-1) else (),
                $create-folders := archive:create-collection-recursively($snapshot-collection, $folders) 
            return 
            if ($data instance of document-node() and $data/cfdb:archive) then () else 
            if ($data-type eq "resource") then if (exists($folders)) then xmldb:store($snapshot-collection||"/"||string-join($folders,"/"), substring-after($path, string-join($folders,"/")||"/"), $data) else xmldb:store($snapshot-collection, $path, $data) else 
            if ($data-type eq "folder") then xmldb:create-collection($snapshot-collection, $path) 
            else ()
        }
    return 
        if (exists($snapshot))
        then 
            let $col := try {
                xmldb:create-collection($archive:repo-path, $id) }
                catch * {
                    <error>An error occured. Could not create collection for snaphot {$id}. ({$err:code} , {$err:description}, {$err:value})</error>
                }
            let $zip-filename := $id||".zip",
                $zip-available := util:binary-doc-available($archive:repo-path||"/"||$zip-filename)
            let $unzip := if (not($zip-available)) then () else   
                try {
                    compression:unzip(util:binary-doc($archive:repo-path||"/"||$zip-filename), $entry-filter, (), $entry-data, ())
                } catch * {
                    <error>An error occured uncompressing the snapshot {$id}. ({$err:code} , {$err:description}, {$err:value})</error>
                }
            let $set-current := if ($unzip instance of element(error)) then () else 
                config:set("deployed-snapshot", $id) 
            return 
                if ($col instance of element(error)) then $col else 
                if (not($zip-available)) then <error>Archive {$zip-filename} not available.</error> else 
                if ($unzip instance of element(error)) then $unzip 
                else $set-current
        else <error>Unknown snapshot {$id}.</error>
};
