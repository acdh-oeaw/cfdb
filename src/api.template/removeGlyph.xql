xquery version "3.0";

(:~ 
 : This XQuery removes a glyph from a tablet and its corresponding surface.    
~:)

declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "xml";
declare option output:media-type "text/xml";
declare option output:exclude-result-prefixes "tei";
declare option output:indent "no";

import module namespace tablet="@app.uri@/tablet" at "xmldb:exist://db/apps/@app.name@/modules/tablet.xqm";
import module namespace config="@app.uri@/config" at "xmldb:exist://db/apps/@app.name@/modules/config.xqm";

declare variable $data external;

let $input := util:parse($data)
let $context-id:= $input/envelope/data/text()
let $log := util:log-app("INFO", $config:app-name, "removing context with ID "||$context-id)
return 
    if ($context-id and $context-id != '')
    then
    	let $glyph-id := replace($context-id,'^context','glyph'),
    		$g := collection($config:tablets-root)//tei:g[@xml:id = $glyph-id],
    		$charDecl-id := replace($context-id,'^context','charDecl')
        let $surface-zone := collection($config:tablets-root)//tei:zone[@xml:id = replace($context-id,'^context','glyph')],
            $surface-uri := base-uri($surface-zone),
            $tablet-zone := collection($config:tablets-root)//tei:zone[@corresp = "#"||$context-id],
            $tablet-uri := base-uri($tablet-zone),
            $tablet-context := collection($config:tablets-root)//tei:seg[@xml:id = $context-id][@type='context'],
            $surface-div :=  collection($config:tablets-root)//tei:div[@corresp = "#"||$glyph-id][@type="imtAnnotation"],
            $tablet-note := collection($config:tablets-root)//tei:note[@target = "#"||$glyph-id],
            $tablet-charDecl := collection($config:tablets-root)//tei:charDecl[@xml:id = $charDecl-id]
        let $glyph-img-url := root($tablet-zone)//tei:graphic[@xml:id = substring-after($g/@facs,'#')],
            $glyph-img := util:collection-name($tablet-zone)||"/"||$glyph-img-url/@url,
            $glyph-img-exists := util:binary-doc-available($glyph-img)
                
                
        return 
            if (exists($surface-div and $tablet-note and $surface-zone and $tablet-zone and $tablet-context))
            then 
                let $log := util:log-app("DEBUG", $config:app-name, "deleting tei:zone in surface")
                let $update := update delete $surface-zone
                let $log := util:log-app("DEBUG", $config:app-name, "deleting annotation div in surface")
                let $update := update delete $surface-div
                let $log := util:log-app("DEBUG", $config:app-name, "deleting tei:zone in tablet")
                let $update := update delete $tablet-zone 
                let $log := util:log-app("DEBUG", $config:app-name, "deleting tei:seg in tablet")
                let $update := update delete $tablet-context
                let $log := util:log-app("DEBUG", $config:app-name, "deleting tei:note in tablet")
                let $update := update delete $tablet-note
                let $log := util:log-app("DEBUG", $config:app-name, "deleting tei:charDecl in tablet")
                let $update := update delete $tablet-charDecl
                let $rm-g-img := 
                    try {xmldb:remove(util:collection-name($glyph-img),util:document-name($glyph-img))}
                    catch * {util:log-app("DEBUG", $config:app-name, "an error occured removing "||$glyph-img)}
                let $log := util:log-app("DEBUG", $config:app-name, "deleting glyph img at "||$glyph-img||" (exists? "||$glyph-img-exists||")")
                return
                <envelope xmlns="" status="success">
                    <data>{$input/envelope/data/text()}</data>
                    <msg>{"Removed glyph "||$context-id||" from database"}</msg>
                </envelope>
            else
                let $log := util:log-app("DEBUG", $config:app-name, "some glyph data components were not found")
                return
                <envelope xmlns="" status="failure">
                    <data>{$input/envelope/data/text()}</data>
                    <msg>{"an error occured: some glyph data components were not found."}</msg>
                </envelope>
            
    else 
        let $log := util:log-app("DEBUG", $config:app-name, "$context-id empty")
        return
        <envelope xmlns="" status="failure">
                <data>{$input/envelope/data/text()}</data>
                <msg>Glyph-id could not be determined, database has not been altered.</msg>
            </envelope>