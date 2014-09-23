xquery version "3.0";

module namespace api = "http://www.oeaw.ac.at/acdh/cuneidb/api";

import module namespace config="http://www.oeaw.ac.at/acdh/cuneidb/config" at "xmldb:exist:///db/apps/cuneidb/modules/config.xqm";

declare function api:response($caller as xs:string, $items as map()*) as element(api:reponse) {
    <response xmlns="http://www.oeaw.ac.at/acdh/cuneidb/api">
        <metadata>
            <query>{$caller}</query>
            <timeStamp>{current-dateTime()}</timeStamp>
            <user>{xmldb:get-current-user()}</user>
        </metadata>
        <body>{
            for $i in $items
            return    
                <item>{
                    for $k in map:keys($i) 
                    let $name := string-join((
                        for $t at $p in tokenize($k,'\s+') 
                        return  
                            if ($p = 1) 
                            then lower-case($t)
                            else upper-case(substring($t,1,1))||lower-case(substring($t,2)) 
                    ),'')
                    return <property name="{$name}">{map:get($i,$k)}</property>
                }</item>
        }</body>
    </response>
};