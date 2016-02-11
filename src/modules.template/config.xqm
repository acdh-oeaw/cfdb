xquery version "3.0";

(:~
 : A set of helper functions to access the application context from
 : within a module.
 :)
module namespace config="@app.uri@/config";

declare namespace templates="http://exist-db.org/xquery/templates";

declare namespace repo="http://exist-db.org/xquery/repo";
declare namespace expath="http://expath.org/ns/pkg";

declare variable $config:debug := false();

(:~ $config:UUID holds a UUID for the instance in quesstion
 : The UUID is generated via the ant build. 
 :)
declare variable $config:UUID := "@instance.uuid@";

(: 
    Determine the application root collection from the current module load path.
:)
declare variable $config:app-root := 
    let $rawPath := system:get-module-load-path()
    let $modulePath :=
        (: strip the xmldb: part :)
        if (starts-with($rawPath, "xmldb:exist://")) then
            if (starts-with($rawPath, "xmldb:exist://embedded-eXist-server")) then
                substring($rawPath, 36)
            else
                substring($rawPath, 15)
        else
            $rawPath
    return
        substring-before($modulePath, "/modules")
;


declare variable $config:path-to-config := $config:app-root||"/config.xml";


declare variable $config:keys := doc($config:path-to-config)/*/*/local-name(.);

declare variable $config:config-valid-values := map {
    "operation-mode" := ("public", "curation")
};


(:~ $config:operation-mode contains the value of the operation-mode setting. 
 : each cfdb instance can work in two modes of operation: either "public mode" or 
 : "curation mode". 
 : Instances operating in "curation mode" contain the full set of data (i.e. full 
 : images and ACL settings for ownership) and serve for corpus curation. Annotators and 
 : editors can create new tablets, surfaces, annotations etc. and edit metdata.    
 : "public" instances are read-only and contain only TEI-files and 
 : cropped glyph images. All tablets are world-readable. Routes to the "edit"-XForms 
 : are disactivated in the controller.  
 :)
declare variable $config:operation-mode := config:get("operation-mode");

(:~ $config:isPublicInstance contains a boolean indicating that operation mode. 
 : "True" when instance is running in public mode.
 :)
declare variable $config:isPublicInstance := $config:operation-mode eq "public"; 




declare variable $config:tablet2html := $config:app-root||"/tablet2html.xsl";

declare variable $config:app-name := "@app.name@";

declare variable $config:domain := "@app.name@.acdh.oeaw.ac.at";

declare variable $config:data-root := "/db/@data.dir@";

declare variable $config:tablets-root := $config:data-root || "/tablets";

declare variable $config:repo-descriptor := doc(concat($config:app-root, "/repo.xml"))/repo:meta;

declare variable $config:expath-descriptor := doc(concat($config:app-root, "/expath-pkg.xml"))/expath:package;

declare variable $config:authorized-users := (sm:get-group-members("cfdbEditors"),sm:get-group-members("cfdbAnnotators"));

declare variable $config:editors := sm:get-group-members("cfdbEditors");

(:~
 : Resolve the given path using the current application context.
 : If the app resides in the file system,
 :)
declare function config:resolve($relPath as xs:string) {
    if (starts-with($config:app-root, "/db")) then
        doc(concat($config:app-root, "/", $relPath))
    else
        doc(concat("file://", $config:app-root, "/", $relPath))
};

(:~
 : Returns the repo.xml descriptor for the current application.
 :)
declare function config:repo-descriptor() as element(repo:meta) {
    $config:repo-descriptor
};

(:~
 : Returns the expath-pkg.xml descriptor for the current application.
 :)
declare function config:expath-descriptor() as element(expath:package) {
    $config:expath-descriptor
};

declare %templates:wrap function config:app-title($node as node(), $model as map(*)) as text() {
    $config:expath-descriptor/expath:title/text()
};

declare function config:app-meta($node as node(), $model as map(*)) as element()* {
    <meta xmlns="http://www.w3.org/1999/xhtml" name="description" content="{$config:repo-descriptor/repo:description/text()}"/>,
    for $author in $config:repo-descriptor/repo:author
    return
        <meta xmlns="http://www.w3.org/1999/xhtml" name="creator" content="{$author/text()}"/>
};

(:~
 : For debugging: generates a table showing all properties defined
 : in the application descriptors.
 :)
declare function config:app-info($node as node(), $model as map(*)) {
    let $expath := config:expath-descriptor()
    let $repo := config:repo-descriptor()
    return
        <table class="app-info">
            <tr>
                <td>app collection:</td>
                <td>{$config:app-root}</td>
            </tr>
            {
                for $attr in ($expath/@*, $expath/*, $repo/*)
                return
                    <tr>
                        <td>{node-name($attr)}:</td>
                        <td>{$attr/string()}</td>
                    </tr>
            }
            <tr>
                <td>Controller:</td>
                <td>{ request:get-attribute("$exist:controller") }</td>
            </tr>
        </table>
};

declare function config:set($map as map()) as item() {
    let $set := for $key in map:keys($map) return config:set($key, map:get($map, $key))
    return 
        if (some $x in $set satisfies $x instance of element(error))
        then <error>{count($set/self::error)} key{if (count($set/self::error) gt 1) then 's' else ''} could not be set: {string-join($set/self::error, ', ')}</error> 
        else   
            (:workaround: calling config:get() here results in a server error, so we have to build the map here locally.:)
            let $entries := doc($config:path-to-config)/config/*
            return map:new(for $e in $entries return map:entry(local-name($e), data($e)))
};

declare function config:set($key as xs:string, $value as xs:string?) as item() {
    let $log := util:log-app("DEBUG", $config:app-name, $key||":"||$value)
    return
    if (not(xmldb:get-current-user() = $config:editors)) then <error>Unsufficient privileges.</error>
    else if (config:get($key) instance of element(error)) then config:get($key)
    else
    let $value-is-valid := 
        if (not(map:contains($config:config-valid-values, $key))) then true()
        else if ($value = map:get($config:config-valid-values, $key)) then true()
        else false()
    let $result :=
        if (not($value-is-valid)) then <error>Invalid value "{$value}" given for key "{$key}".</error>
        else 
            try {
                if ($value = "" or not($value))
                then update delete doc($config:path-to-config)//*[local-name() = $key]/text()
                else update value doc($config:path-to-config)//*[local-name() = $key] with $value
            } catch * {
                <error>Could not set configuration key "{$key}". ({$err:code} , {$err:description}, {$err:value})</error>
            }
    return 
        if ($result instance of element(error))
        then $result
        else 
            (:workaround: calling config:get() here results in a server error, so we have to build the map here locally.:)
            let $entries := doc($config:path-to-config)/config/*
            return map:new(for $e in $entries return map:entry(local-name($e), data($e)))

};


declare function config:get() as item() {
    config:get()
};

declare function config:get($key as xs:string?) as item() {
    if (exists($key))
    then 
        if (not(exists(doc($config:path-to-config)/config/*[local-name() = $key]))) 
        then <error>Unknown key "{$key}"</error>
        else doc($config:path-to-config)/config/*[local-name() = $key]/data(.)
    else 
        let $entries := doc($config:path-to-config)/config/*
        return map:new(for $e in $entries return map:entry(local-name($e), data($e)))
};

