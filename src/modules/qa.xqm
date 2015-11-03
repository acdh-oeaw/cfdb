xquery version "3.0";

module namespace qa = "http://www.oeaw.ac.at/acdh/cfdb/qa";
import module namespace config="http://www.oeaw.ac.at/acdh/cfdb/config" at "config.xqm";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare variable $qa:namespace := "http://www.oeaw.ac.at/acdh/cfdb/qa";

(:~
 : This module contains quality assurance functions, i.e. tests on the data integrity and validity. 
 :)
 
 declare %private function qa:result($test as xs:string, $desc, $assumptions as xs:string*, $status as xs:integer, $warn as xs:string?, $reason as xs:string?, $results as map*) {
    <qa:test-results xml:id="{$test}">
        <qa:description>{$desc}</qa:description>
        {if ($assumptions)
        then <qa:assumptions>{for $a in $assumptions return <qa:test ref="#{$a}"/>}</qa:assumptions>
        else ()}
        {if ($warn)
        then <qa:warn>{$warn}</qa:warn>
        else ()}
        <qa:valid>{if ($status = 0) then 'true' else 'false'}</qa:valid>
        {if ($status > 0) 
        then (
            <qa:fails>{count($results)}</qa:fails>,
            <qa:reason>{$reason}</qa:reason>
        )
        else ()}
        {for $r in $results return 
            <qa:issue>{
                for $k in map:keys($r)
                return element {"qa:"||$k} {map:get($r, $k)}
            }</qa:issue>}
    </qa:test-results>
};

declare %private function qa:test($name as xs:string, $description as xs:string, $failing-nodes as item()*) as element(qa:test) {
    qa:test(
        $name,
        $description,
        (),
        $failing-nodes
    )
};

declare %private function qa:test($name as xs:string, $description as xs:string, $assumptions as xs:string*, $failing-nodes as item()*) as element(qa:test) {
    let $assumptions-tests := 
            for $a in $assumptions 
                let $function := 
                    try {
                        function-lookup(QName($qa:namespace, $a), 0)
                    } catch * {
                        ()
                    }
                return 
                    if (exists($function))
                    then ($function())
                    else ()
    let $assumptions-met := exists($assumptions-tests//qa:valid = 'false')
    let $warn := 
        if (count($assumptions-tests) != count($assumptions))
        then "some functions for assumptions were not found"
        else ()
    let $status := (
        if (count($assumptions) gt 0) then if (not($assumptions-met)) then 0 else () else (),
        if (exists($failing-nodes)) then 1 else 0
    )[1]
    
    let $reason :=
        if ($assumptions-met) 
        then "one or more assumptive tests were not successful" 
        else "did not match requirement"
    return qa:result($name, "This tests ensures that "||$description||".", $assumptions, $status, $warn, $reason, $failing-nodes)
};


(:~
 : This function tests, if there exists only one note to each g-Element.
 :)
declare function qa:one-note-per-glyph() as element() {
    let $failing-nodes := 
        for $n in collection($config:tablets-root)//tei:note
        group by $t := $n/@target
        order by $t
        return
            let $tid := $n/root()/tei:TEI/@xml:id
            return
                if (count($n) gt 1)
                then map {
                        "tablet-id" := $tid,
                        "note-id" := xs:string($t)
                }
                else ()
    return qa:test(
        "one-note-per-glyph",
        "there is only one note for each sign",
        $failing-nodes
    )
};


(:~
 : This function tests, if there exists only one q-Element in each seg type context:
 :)
declare function qa:one-reading-per-context() as element() {
    let $failing-nodes :=   
        for $i in collection($config:tablets-root)//tei:seg[@type = 'context'][count(tei:g) gt 1] 
        return
            map {
                "tablet-id" := root($i)/tei:TEI/xs:string(@xml:id),
                "context-id" := $i/xs:string(@xml:id)
             }
    return qa:test(
        "one-reading-per-context",
        "there is only one reading for each context",
        $failing-nodes
    )
};


declare function qa:note-exists-for-context() as element() {
    let $failing-nodes :=
        for $c in collection($config:tablets-root)//tei:seg[@type = 'context']/tei:g
            return
            if (not(exists(root($c)//tei:note[@target = "#"||$c/@xml:id])))
            then
                map {
                    "tablet-id" := root($c)/tei:TEI/xs:string(@xml:id),
                    "context-id" := $c/xs:string(@xml:id)
                 }
            else ()

    return qa:test(
        "note-for-context",
        "there exists exactly one note for each context",
        "one-reading-per-context",
        $failing-nodes
    )
};

