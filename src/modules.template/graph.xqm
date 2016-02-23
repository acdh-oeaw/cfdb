xquery version "3.0";

(:~ This modules declares functions that feed graph views of the database's content. Each graph is defined 
    as a function with the annotatoin %graph:graph. A description is given by the annotation %graph:description.
    Each function can be accessed with the function graph:get-data($graph-name) where $graph-name is the local name 
    of the function to be called. By now, graph functions take no parameters, this can be changed in the future. 
    All graph functions must return a <graph:data> element containing zero or more <graph:row> elements with 
    one or more <graph:value> elements. 
 :)

module namespace graph = "http://www.oeaw.ac.at/acdh/cfdb-graphs/graph";
import module namespace config="http://www.oeaw.ac.at/acdh/cfdb-graphs/config" at "xmldb:exist:///db/apps/cfdb-graphs/modules/config.xqm";
import module namespace cfdb = "http://www.oeaw.ac.at/acdh/cfdb-graphs/db" at "xmldb:exist:///db/apps/cfdb-graphs/modules/cfdb.xqm";
import module namespace tablet = "http://www.oeaw.ac.at/acdh/cfdb-graphs/tablet" at "xmldb:exist:///db/apps/cfdb-graphs/modules/tablet.xqm";
import module namespace surface = "http://www.oeaw.ac.at/acdh/cfdb-graphs/surface" at "xmldb:exist:///db/apps/cfdb-graphs/modules/surface.xqm";
import module namespace annotation = "http://www.oeaw.ac.at/acdh/cfdb-graphs/annotations" at "xmldb:exist:///db/apps/cfdb-graphs/modules/annotations.xqm";
import module namespace archive = "http://www.oeaw.ac.at/acdh/cfdb-graphs/archive" at "xmldb:exist:///db/apps/cfdb-graphs/modules/archive.xqm";
import module namespace xqjson = "http://xqilla.sourceforge.net/lib/xqjson";
import module namespace app="http://www.oeaw.ac.at/acdh/cfdb-graphs/templates" at "xmldb:exist:///db/apps/cfdb-graphs/modules/app.xql";

declare namespace tei = "http://www.tei-c.org/ns/1.0";


declare function graph:get-data($name as xs:string) {
    let $f := 
        try {
            fn:function-lookup(QName("http://www.oeaw.ac.at/acdh/cfdb-graphs/graph", $name), 0)
        } catch * {
            <error>An error occured looking up graph function graph:{$name} in graph.xqm. ({$err:code} , {$err:description}, {$err:value})</error>
        }
    return 
        if (count($f) gt 0)
        then $f()
        else <error>Function graph:{$name} not found in module graph.xqm</error>
};


declare function graph:list() {
    let $functions := inspect:module-functions()
    return 
        for $f in $functions  
        let $in := inspect:inspect-function($f),
            $desc := $in//annotation[@name = 'graph:description']/value/text()
        where $in//annotation/@name = 'graph:graph'
        return <graph:graph name="{$in/substring-after(@name, ':')}"><graph:description>{$desc}</graph:description></graph:graph>
};

declare 
    %graph:graph 
    %graph:description("A list with two columns: signs types (standard signs) and absolut number of occurences in the corpus.") 
function graph:signTypes() {     
    let $annos := cfdb:list-annotations()
    let $results :=
        for $g in $annos//annotation 
        let $type := $g/sign/xs:string(.)
        group by $type 
        order by count($g) descending
        return <graph:row>  
                    <graph:value name="type">{$type}</graph:value>
                    <graph:value name="count">{count($g)}</graph:value>
               </graph:row>
    return <graph:data rows="{count($results)}">{$results}</graph:data>
};

