xquery version "3.0";

(:~ This modules declares functions that feed graph views of the database's content. Each graph is defined 
 :  as a function annotated with %graph:provides-data-for() that describes which graph can be 
 :  rendered with its data, e.g. %graph:provides-data-for("a graph showing the distribution of tablets over periods in the corpus.").
 :  
 :  All graph functions can be accessed by one single getter function, graph:get-data($name) where $name is the local name 
 :  of the graph function to be called. By now, graph functions take no parameters, this can be changed in the future.
 : 
 :  Each graph function must return a <graph:data rows="total-number-of-rows"> element containing zero or more <graph:row> elements with 
 :  one or more <graph:value name="" type=""> elements.
 : 
 :  A list of available graph endpoints is provided by the graph:list() function.  
 :)

module namespace graph = "@app.uri@/graph";
import module namespace config="@app.uri@/config" at "xmldb:exist:///db/apps/@app.name@/modules/config.xqm";
import module namespace cfdb = "@app.uri@/db" at "xmldb:exist:///db/apps/@app.name@/modules/cfdb.xqm";
import module namespace tablet = "@app.uri@/tablet" at "xmldb:exist:///db/apps/@app.name@/modules/tablet.xqm";
import module namespace surface = "@app.uri@/surface" at "xmldb:exist:///db/apps/@app.name@/modules/surface.xqm";
import module namespace annotation = "@app.uri@/annotations" at "xmldb:exist:///db/apps/@app.name@/modules/annotations.xqm";
import module namespace archive = "@app.uri@/archive" at "xmldb:exist:///db/apps/@app.name@/modules/archive.xqm";
import module namespace xqjson = "http://xqilla.sourceforge.net/lib/xqjson";
import module namespace app="@app.uri@/templates" at "xmldb:exist:///db/apps/@app.name@/modules/app.xql";

declare namespace tei = "http://www.tei-c.org/ns/1.0";
declare namespace json = "http://www.json.org";

declare function graph:get-data($name as xs:string) {
    let $f := 
        try {
            fn:function-lookup(QName("@app.uri@/graph", $name), 0)
        } catch * {
            <error>An error occured looking up graph function graph:{$name} in graph.xqm. ({$err:code} , {$err:description}, {$err:value})</error>
        }
    return 
        if (count($f) gt 0)
        then $f()
        else <error>Function graph:{$name} not found in module graph.xqm</error>
};


(:~ This function returns a list of currently available graph sources by 
 : inspecting the present module and looking for functions with the %graph:graph 
 : annotation.
 : @return one element for each graph endpoint in the format <graph:endpoint name="local-name-of-graph-function"><graph:description>Description text</graph:description></graph:endpoint> 
 :)
declare function graph:list() as element(graph:endpoints) {
    let $functions := inspect:module-functions()
    let $endpoints := 
        for $f in $functions  
        let $in := inspect:inspect-function($f),
            $desc := $in//annotation[@name = 'graph:provides-data-for']/value/text(),
            $name := $in/substring-after(@name, ':')
        where $desc != ''
        return <graph:endpoint><graph:name>{$name}</graph:name><graph:description>{$desc}</graph:description></graph:endpoint>
    return <graph:endpoints>{$endpoints}</graph:endpoints>
};


declare 
    %graph:provides-data-for("a graph showing the distribution of sign types (standard signs) over the corpus.") 
function graph:standardSignDistribution() {     
    let $annos := cfdb:list-annotations()
    let $results :=
        for $g in $annos//annotation 
        let $type := $g/sign/xs:string(.)
        group by $type 
        order by count($g) descending
        return <graph:row>  
                    <graph:value name="type" type="string">{$type}</graph:value>
                    <graph:value name="count" type="number">{count($g)}</graph:value>
               </graph:row>
    return <graph:data
        items="{count($results)}"
        title="Signs per Type"
        subtitle="A bar chart showing the distribution of sign types (standard signs) over the corpus."
        legendx="Signs"
        legendy="Number of Signs"
         measuredObject="Signs">{$results}</graph:data>
};

declare  
    %graph:provides-data-for("a graph showing the distribution of tablets over periods in the corpus.") 
 function graph:periodDistribution() {     
    let $tablets := cfdb:tablets()
    let $taxonomies := doc($config:etc-root||"/taxonomies.xml"
    let $results :=
        for $t in $tablets 
        let $period := $t//tei:date/@period
        let $period := $taxonomies//tei:taxonomy[@xml:id = 'periods']/tei:category[@xml:id = $t//tei:origDate/tei:date/@period]/tei:catDesc

        group by $period
        order by count($t) descending
        return <graph:row>  
                    <graph:value name="period" type="string">{xs:string($period)}</graph:value>
                    <graph:value name="count" type="number">{count($t)}</graph:value>
               </graph:row>
    return <graph:data items="{count($results)}"
        title="Tablets per Periode"
        subtitle="A bar chart showing the distribution of tablets over periods in the current corpus."
        legendx="Period"
        legendy="Number of Tablets"
        measuredObject="Tablets">{$results}</graph:data>
};

declare  
    %graph:provides-data-for("a graph showing the distribution of tablets over regions in the corpus.") 
 function graph:regionDistribution() {     
    let $tablets := cfdb:tablets()
    let $results :=
        for $t in $tablets 
        let $region := $t//tei:region
        group by $region
        order by count($t) descending
        return <graph:row>  
                    <graph:value name="region" type="string">{xs:string($region)}</graph:value>
                    <graph:value name="count" type="number">{count($t)}</graph:value>
               </graph:row>
    return <graph:data items="{count($results)}"
        title="Tablets per Regions"
        subtitle="A bar chart showing the distribution of tablets over regions in the current corpus."
        legendx="Region"
        legendy="Number of Tablets"
        measuredObject="Tablets">{$results}</graph:data>
};


