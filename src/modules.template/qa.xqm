xquery version "3.0";

module namespace qa = "@app.uri@/qa";
import module namespace config="@app.uri@/config" at "config.xqm";
import module namespace cfdb="@app.uri@/cfdb" at "cfdb.xqm";
declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare variable $qa:namespace := "@app.uri@/qa";

(:~
 : This module contains quality assurance functions, i.e. tests on the data integrity and validity. 
 :)
 
 declare %private function qa:result($test as xs:string, $desc, $assumptions as xs:string*, $status as xs:integer, $warn as xs:string?, $reason as xs:string?, $results as map(*)*) {
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
                return element {"qa:"||$k} {xs:string(map:get($r, $k))}
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
    return qa:result($name, "This test ensures that "||$description||".", $assumptions, $status, $warn, $reason, $failing-nodes)
};


(: This function runs all registered qa tests :)
declare function qa:run() as element()*{(
    qa:one-note-per-glyph(),
    qa:one-reading-per-context(),
    qa:note-exists-for-context(),
    qa:only-one-xml-file-in-tablet-collection(),
    qa:every-legacy-format-tablet-has-all-glyphs(),
    qa:all-sign-numbers-are-integers()
)};



(:~
 : This function tests if there exists only one note to each g-Element.
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
 : This function tests if there exists only one q-Element in each seg type context:
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


(:~
 : This function tests if there exists a note element for each context.
 :)
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

(:~
 : This function tests if there exists only one TEI-XML file in a tablet collection (the old IMT setup had one TEI file for each surface and one TEI file for the whole tablet. This leads to unexpected behavior.)
 :)
declare function qa:only-one-xml-file-in-tablet-collection() as element(){
    let $tablets := 
        for $c in xmldb:get-child-collections($config:tablets-root)
        let $path := $config:tablets-root||"/"||$c
        let $resources := xmldb:get-child-resources($path)
        return <c path="{$path}" name="{$c}">{
            for $r in $resources 
            let $mime-type := xmldb:get-mime-type(xs:anyURI($path||"/"||$r))
            return
            <r mime-type="{$mime-type}">{$r}</r>
        }</c>
    let $failing-tablets := 
        for $t in $tablets[count(r[@mime-type='application/xml'][.!='__contents__.xml']) gt 1]
        return map {
            "tablet-id" := $t/xs:string(@name),
            "filenames" := string-join($t/r[@mime-type = 'application/xml'][.!='__contents__.xml'][not(starts-with(.,'tablet'))],'&#10;')
        }
    return qa:test("legacy-format", "there is no tablet collection that contains more than one XML file", $failing-tablets)
};

(:~
 : This function tests if every zone element in a surface TEI-XML (legacy setup) has a corresponding annotation in the combined tablet TEI file.
 :)
declare function qa:every-legacy-format-tablet-has-all-glyphs() as element()*{
    let $tablets := 
        for $c in xmldb:get-child-collections($config:tablets-root)
        let $path := $config:tablets-root||"/"||$c
        let $resources := xmldb:get-child-resources($path)
        return <c path="{$path}" name="{$c}">{
            for $r in $resources 
            let $mime-type := xmldb:get-mime-type(xs:anyURI($path||"/"||$r))
            return
            <r mime-type="{$mime-type}">{$r}</r>
        }</c>
    let $tablets-with-more-than-one-xml-file := $tablets[count(r[@mime-type='application/xml'][.!='__contents__.xml']) gt 1]
    let $failing-tablets := 
        for $t in $tablets-with-more-than-one-xml-file
            let $combined-tablet := $t/r[@mime-type = 'application/xml'][.!='__contents__.xml'][starts-with(.,'tablet')]/doc(parent::*/@path||"/"||.)
            let $imt-surfaces := $t/r[@mime-type = 'application/xml'][.!='__contents__.xml'][not(starts-with(.,'tablet'))]/doc(parent::*/@path||"/"||.)
            let $fails :=  
                for $zone-id in $imt-surfaces//tei:zone/@xml:id
                let $context-in-combined-tablet := $combined-tablet//tei:g[@xml:id = $zone-id]
                return 
                    if (exists($context-in-combined-tablet))
                    then ()
                    else map {
                        "tablet-id" := $t/xs:string(@name),
                        "zone" :=  $zone-id
                    }
        return $fails
    return qa:test("every-legacy-format-tablet-has-all-glyphs", "there is no glyph missing in a combined surface tablet that has been annotated with the Image Markup Tool", $failing-tablets)
};

(:~ This function tests if all @n attributes on standard signs can be cast to xs:integer 
 :)
declare function qa:all-sign-numbers-are-integers() as element()* {
   let $test-name := "all-sign-numbers-are-integers",
       $description := (:This test ensures that :) "every sign number can be cast to an integer"
   let $not-castable-n-attributes := 
       for $s in $cfdb:stdSigns[not(matches(@n,'^\d+$'))]
       return map{"sign-id" := $s/@xml:id, "sign-n" := $s/@n}
   return qa:test($test-name, $description, $not-castable-n-attributes)
};

(:~ This function tests for permission settings in the data-collection 
 :)
declare function qa:data-permissions-are-valid() as element()* {
   ()
};

