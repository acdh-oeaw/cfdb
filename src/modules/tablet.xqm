xquery version "3.0";

module namespace tablet = "http://www.oeaw.ac.at/acdh/cuneidb/tablet";
import module namespace config="http://www.oeaw.ac.at/acdh/cuneidb/config" at "xmldb:exist:///db/apps/cuneidb/modules/config.xqm";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare variable $tablet:template-filepath := $config:app-root||"/template.xml";
declare variable $tablet:template := doc($tablet:template-filepath);

declare variable $tablet:seed-xsl-filepath := $config:app-root||"/seed.xsl";
declare variable $tablet:seed-xsl := doc($tablet:seed-xsl-filepath);

(: erstellt neue Tafel anhand eines hochgeladenen Bildes :)
declare function tablet:new($path-to-img as xs:anyURI) {(: as empty() { :)
    let $filename := tokenize($path-to-img,'/')[last()],
        $collection := substring-before($path-to-img,$filename),
        $height := image:get-height(util:binary-doc($path-to-img)),
        $width := image:get-width(util:binary-doc($path-to-img))
    
    let $parameters := 
        <parameters>
            <param name="filename" value="{$filename}"/>
            <param name="title" value="{translate(replace($filename,'\..+$',''),'_',' ')}"/>
            <param name="height" value="{$height}px"/>
            <param name="width" value="{$width}px"/>
        </parameters>
    
    let $IMT-file := transform:transform($tablet:template, $tablet:seed-xsl, $parameters)/self::tei:TEI
    return 
        switch(true())
            case (not(util:binary-doc-available($path-to-img))) return <error>{$path-to-img} is not available</error>
            case (doc-available($collection||"/"||replace($filename,'\..+$','.xml'))) return <error>file already exists</error>
            default return xmldb:store($collection, replace($filename,'\..+$','.xml'), $IMT-file)
};

declare function tablet:get($id as xs:string) as element(tei:TEI)? {
    collection($config:data-root)//tei:TEI[@xml:id = $id]
};


declare function tablet:update($id as xs:string, $data as element(tei:TEI)) as empty() {
    let $data := tablet:get($id),
        $filepath := base-uri($data),
        $filename := tokenize($filepath,'/'),
        $path := substring-before('/'||$filename,$filepath)
    return xmldb:store($filename,$path,$data)
};


declare function tablet:remove($id as xs:string) as empty() {
    let $data := tablet:get($id),
        $filepath := base-uri($data),
        $filename := tokenize($filepath,'/'),
        $path := substring-before('/'||$filename,$filepath)
    return xmldb:remove($path,$filename)
};

declare function  tablet:extractGlyphs($tablet as element(tei:TEI)) {
    let $tablet-id := $tablet/@xml:id
    let $imt2tei := transform:transform($tablet, doc('IMT2TEI.xsl'),())
    let $snippets := 
        for $zone in $imt2tei//tei:zone[@rendition="cuneiform"]
            let $glyph-id := $zone/@xml:id,
                $graphic := $zone/parent::tei:surface/tei:graphic,
                $img-filepath := util:collection-name($tablet)||"/"||replace($graphic/@url,'\\','/')
            return
                if (util:binary-doc-available($img-filepath))
                then 
                    let $img-crop := image:crop(util:binary-doc($img-filepath),$zone/(@ulx,@uly,xs:integer(@lrx)-xs:integer(@ulx),xs:integer(@lry)-xs:integer(@uly)),"image/png"),
                        $img-collection := $config:data-root||"/_glyphs/",
                        $create-tablet-collection := 
                            if (exists(collection($img-collection||"/"||$tablet-id)))
                            then ()
                            else xmldb:create-collection($img-collection,$tablet-id) 
                    return xmldb:store($img-collection||"/"||$tablet-id,$glyph-id||".jpg",$img-crop) 
                else "image at "||$img-filepath||" is not available"
    return $imt2tei
}; 

declare function tablet:list()  {
    let $data := collection($config:data-root)//tei:TEI[tei:text/@type='tablet']
    return 
        <tablets xmlns="">{
            for $d in $data 
            return 
                <tablet>
                    <id>{$d/xs:string(@xml:id)}</id>
                    <title>{$d/tei:teiHeader/tei:fileDesc/tei:titleStmt/data(tei:title)}</title>
                    <filename>{base-uri($d)}</filename>
                </tablet>
        }</tablets>
};
