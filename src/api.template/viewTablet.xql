xquery version "3.0";


declare namespace tei = "http://www.tei-c.org/ns/1.0";

import module namespace config="@app.uri@/config" at "xmldb:exist:///db/apps/@app.name@/modules/config.xqm";

import module namespace tablet="@app.uri@/tablet" at "xmldb:exist:///db/apps/@app.name@/modules/tablet.xqm";

declare variable $data external;

let $log := util:log-app("DEBUG",$config:app-name, "viewTablet.xql called by "||xmldb:get-current-user())
let $input := util:parse($data)
let $tablet-id := $input//id
let $log := util:log-app("DEBUG",$config:app-name, "$tablet-id = "||$tablet-id)
return 
    if ($tablet-id = '')
    then <p xmlns="http://www.w3.org/1999/xhtml">Error: tablet-id = ''</p>
    else 
        let $tablet := tablet:get($tablet-id),
            $xsl := try{
                        if (doc-available($config:tablet2html)) then
                                doc($config:tablet2html)
                            else ()
                    } catch * {
                        util:log-app("ERROR", $config:app-name, $err:code || $err:description || $err:value)
                    }
        let $html := if ($xsl) then
                        let $ps :=   <parameters>
                                        <param name="taxonomies.path" value="{$config:data-root}/etc/taxonomies.xml"/>
                                    </parameters>
                        return transform:transform($tablet,$xsl, $ps)
                     else <p xmlns="http://www.w3.org/1999/xhtml">{$config:tablet2html} not available.</p>
        return $html 