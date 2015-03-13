xquery version "3.0";

declare namespace cfdb = "http://acdh.oeaw.ac.at/cfdb";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

import module namespace config="http://www.oeaw.ac.at/acdh/cuneidb/config" at "xmldb:exist:///db/apps/cuneidb/modules/config.xqm";
import module namespace tablet="http://www.oeaw.ac.at/acdh/cuneidb/tablet" at "xmldb:exist:///db/apps/cuneidb/modules/tablet.xqm";
import module namespace a = "http://www.oeaw.ac.at/acdb/cuneidb/annotations" at "xmldb:exist///db/apps/annotorious-test/annotations.xqm";

(:declare option output:method = "application/json"; :)
declare function local:respond($status, $msg) {
    <cfdb:response><status>{$status}</status><msg>{$msg}</msg></cfdb:response>
};

let $allowed-modes := ("POST", "DELETE")

let $data := request:get-uploaded-file-data("file"),
    $filename := request:get-uploaded-file-name("file"),
    $width := request:get-parameter("width", ""),
    $height := request:get-parameter("height", ""),
    $tablet-id := request:get-parameter("tablet-id", ""),
    $mode := request:get-method(),
    $tablet := tablet:get($tablet-id)

return 
    switch (true())
        case ($tablet-id = "") 
            return local:respond("error", "tablet-id must be provided")
        case (not($tablet)) 
            return local:respond("error", "tablet "||$tablet-id||" not found")
        case ($mode = "add" and $width = "") 
            return local:respond("error", "parameter width must not be empty") 
        case ($mode = "add" and $height = "") 
            return local:respond("error", "parameter height must not be empty")
        case ($mode = "add" and not($height castable as xs:integer))
            return local:respond("error", "parameter height must be of type integer ")
        case ($mode = "add" and not($width castable as xs:integer))
            return local:respond("error", "parameter width must be of type integer ")
        case ($mode = "add" and not(exists($data)))
            return local:respond("error", "uploaded data missing")
        case ($filename = "")
            return local:respond("error", "filename could not be determined")
        case ($mode = "")
            return local:respond("error", "mode could not be determined")
        case (not($mode = $allowed-modes))
            return local:respond("error", "unknown mode '"||$mode||"'")
        case $mode = "POST" return 
            let $path := tablet:path($tablet-id),
                $no := count($tablet//tei:surface) + 1,
                $ext := tokenize($filename,'\.')[last()],
                $filename := $tablet-id||"_s"||$no||"."||$ext
            let $store := xmldb:store($path, $filename, $data),
                $insert :=  
                    if ($store != '')
                    then update insert <surface xmlns="http://www.tei-c.org/ns/1.0"><graphic url="{$filename}" width="{$width}px" height="{$height}px"/></surface> into $tablet//tei:sourceDoc
                    else ()
            return
                switch (true())
                    case ($store = "") return local:respond("error", "could not store image at "||$path||"/"||$filename)
                    default return local:respond("success", "Added new surface "||$filename)
                    
        case $mode = "DELETE" return 
            let $path := tablet:path($tablet-id),
                $surface := $tablet//tei:surface[tei:graphic/@url = $filename],
                $annotation-ids := $surface/tei:zone!substring-after(@corresp,'#context_')
            return 
                if (not(util:binary-doc-available($path||"/"||$filename)))
                then local:respond("error", "file not available at "||$path||"/"||$filename)
                else 
                    let $rm-img := 
                        try {xmldb:remove($path, $filename)}
                        catch * {local:respond("error", "Could not delete file at "||$path||"/"||$filename)}
                    let $rm-annotations := $annotation-ids!a:delete($tablet-id, $filename, .)
                    let $rm-surface := update delete $surface
                    return local:respond("success", "removed surface "||$filename)
        
        default return local:respond("error", "unsopported HTTP method "||$mode)