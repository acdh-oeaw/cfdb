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
                <dcterms:URL>{($pid, $config:map("public-url")||"/archive/"||$version)[1]}</dcterms:URL>                
                <dc:creator>{xmldb:get-current-user()}</dc:creator>
                <dcterms:issued>{current-dateTime()}</dcterms:issued>
                <dc:publisher>{$config:map("publisher")}</dc:publisher>
                <dcterms:extent>{count($all-tablets//tei:g)} annotated signs, {count($all-tablets)} tablets, {count(($tablets-data-paths, $etc-data-paths))} files</dcterms:extent>
                <dcterms:license>{$config:map("license")}</dcterms:license>
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
    collection($archive:repo-path)//cfdb:archive
};

declare function archive:remove($identifier) {
    let $remove := 
        try {
            if (util:binary-doc-available($archive:repo-path||"/"||$identifier||".zip"))
            then (xmldb:remove($archive:repo-path, $identifier||".zip"))
            else (),
            if (doc-available($archive:repo-path||"/"||$identifier||".xml"))
            then (xmldb:remove($archive:repo-path, $identifier||".xml"))
            else ()
        } catch * {
            <error>An error occured. Could not remove snapshot {$identifier}. ({$err:code} , {$err:description}, {$err:value})</error>
        } 
    return $remove 
};

declare function archive:import($url as xs:anyURI){
    let $request := <http:request method="GET" href="{$url}"/>,
        $response := http:send-request($request),
        $status := $response/@status,
        $msg := $response/@message
    let $data := 
        if ($status = 200)
        then $response/http:body
        else ()
    return 
        if (exists($data)) 
        then xmldb:store($archive:repo-path, "name.zip", $data, "application/zip") 
        else () 
};

(:compression:unzip(util:binary-doc($a/@path), $entry-filter, (), $entry-data, ()):)
 