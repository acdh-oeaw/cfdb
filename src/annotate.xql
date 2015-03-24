xquery version "3.0";
import module namespace tablet = "http://www.oeaw.ac.at/acdh/cuneidb/tablet" at "modules/tablet.xqm";
import module namespace surface = "http://www.oeaw.ac.at/acdh/cuneidb/surface" at "modules/surface.xqm";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "html";
declare option output:media-type "text/html";

let $cfdb-relpath := "../cuneidb",
    $tablets := tablet:list()

let $tablet-id := request:get-parameter("t", ""),
    $tablet := if ($tablet-id = '') then () else tablet:get($tablet-id),
    $surfaces := if ($tablet-id = '') then () else tablet:listSurfaces($tablet),
    $surface-id := request:get-parameter("s", $surfaces[1]/tei:graphic[1]/xs:string(@url)),
    $surface-available := if ($tablet-id = '' or not($tablet) or $surface-id = '') then false() else surface:exists($tablet, $surface-id)


let $js := "var cfdb = {}; cfdb.surface = {}; cfdb.tablet = '"||$tablet-id||"';&#10;cfdb.surface.id = '"||$surface-id||"';" 
return


<html xmlns="http://www.w3.org/1999/xhtml">
    <head>
        <title>Tablet Annotator</title>
        <script src="resources/js/jquery-2.1.3.min.js" type="text/javascript">//</script>
        <script src="resources/js/jquery-ui-1.11.3/jquery-ui.min.js" type="text/javascript">//</script>
        <link href="resources/js/jquery-ui-1.11.3/jquery-ui.min.css" rel="stylesheet"/>
        
        <link rel="stylesheet" href="resources/css/font-awesome.min.css"/>
        
        <script type="text/javascript" src="resources/js/cropper.min.js">//</script>
        <link href="resources/css/cropper.min.css" rel="stylesheet"/>
        <script type="text/javascript" src="resources/js/plupload.full.min.js">//</script>
        <script type="text/javascript" src="resources/js/jquery.ui.plupload/jquery.ui.plupload.min.js">//</script>
        <link href="resources/js/jquery.ui.plupload/css/jquery.ui.plupload.css" rel="stylesheet"/>
        
        <link href="resources/css/annotate.css" rel="stylesheet"/>
        
        {if ($tablet-id != '')
        then 
            (
            <script type="text/javascript">{$js}</script>,
            <script type="text/javascript" src="resources/js/annotate.js">//</script>
            )
        else ()}
    </head>
    <body>
        {if ($tablet-id !='') then (
        <div id="menu">
            <form id="fm-surface">
                <span class="currentUser">current user: {xmldb:get-current-user()}</span>
                <input type="hidden" name="t" value="{$tablet-id}"/>
                <select name="s" id="sel-surface">{
                    for $s in $surfaces 
                    return 
                        <option value="{$s/tei:graphic[1]/xs:string(@url)}">{(
                            if ($s/tei:graphic[1]/@url = $surface-id)
                            then attribute selected { "selected" }
                            else (),
                            $s/tei:graphic[1]/util:unescape-uri(xs:string(@url),'utf-8')
                        )}</option>
                }</select>
            </form>
            <a href="#" id="addSurface" class="menuitem"><span class="fa fa-plus"></span>&#160;add image</a>
            <a href="#" id="removeSurface" class="menuitem"><span class="fa fa-trash"></span>&#160;remove image</a>
            <a href="annotate.xql" id="switchTablet" class="menuitem"><span class="fa fa-refresh"></span>&#160;select another tablet</a>
            <span id="zoomControlsContainer">
                <a href="#" id="zoomin" class="menuitem"><span class="fa fa-search-plus"></span></a>
                <a href="#" id="zoomout" class="menuitem"><span class="fa fa-search-minus"></span></a>
            </span>
            <div id="uploader">
                <div id="filelist">Your browser doesn't have Flash, Silverlight or HTML5 support.</div>
                <br />
                 
                <div id="container">
                    <a id="pickfiles" href="javascript:;">[Select files]</a>
                    <a id="uploadfiles" href="javascript:;">[Upload files]</a>
                </div>
                 
                <br />
                <pre id="console"></pre>
            </div>
        </div>, 
        
        <div id="details">
            <h3>Details</h3>
            <div id="detailsContent">
                <!-- annotation details loaded here -->
            </div>
        </div>,
        
        <div id="dialog-confirmAnnotationRemove">
            <p>Are you sure to delete the selected annotation?</p>
        </div>,
        
        <div id="dialog-confirmSurfaceRemove">
            <p>Are you sure to delete the current image and all annotated signs on it?</p>
        </div>,
        
        <div id="dialog-edit">
            <form>
                <fieldset>
                    <table>
                        <tr>
                            <td><label for="sign">Sign</label></td>
                            <td>
                                <select name="sign" id="sign" class="ui-widget-content ui-corner-all">
                                    <option>dummy</option>
                                </select>
                            </td>
                        </tr>
                        <tr>
                            <td><label for="reading">Reading</label></td>
                            <td><input type="text" name="reading" id="reading" class="text ui-widget-content ui-corner-all"/></td>
                        </tr>
                        <tr>
                            <td><label for="context">Context</label></td>
                            <td><input type="text" name="context" id="context" class="text ui-widget-content ui-corner-all"/></td>
                        </tr>
                        <tr>
                            <td><label for="sequence">Sequence</label></td>
                            <td><input type="text" name="sequence" class="text ui-widget-content ui-corner-all"/></td>
                        </tr>
                        <tr>
                            <td><label for="note">Note</label></td>
                            <td><textarea type="text" name="note" id="note" class="textarea ui-widget-content ui-corner-all">&#10;</textarea></td>
                        </tr>
                    </table>
                    <input type="hidden" name="x"/>
                    <input type="hidden" name="y"/>
                    <input type="hidden" name="width"/>
                    <input type="hidden" name="height"/>
                    <input type="hidden" name="uuid"/>
                </fieldset>
            </form>
        </div>,
        
        <div id="listContainer">
            <form id="filterList">
                <input name="filter" placeholder="filter by annotation content" title="filter by annotation content"/>
                <a href="#" class="fa fa-search">&#160;</a>
                <div id="slider-thumbnailHeight" title="set thumbnail size">
                    <!-- slider for setting thumbnail height -->
                </div>
            </form> 
            <div id="list">
                <!-- container for ajax loaded sign list -->
            </div>
        </div>)
        else ()
        }
        
        <div id="main">{
            switch(true())
                case ($tablet-id = '') return
                    <form id="selectTabletDialog">
                        <p>Please select a tablet:</p>
                        <select name="t">{
                            for $t in $tablets
                            let $title := $t("title"),
                                $id := $t("id")
                            order by $title ascending
                            return <option value="{$id}">{$title}</option>
                       }</select>
                        <button type="submit">load</button>
                    </form>
                
                case ($surface-id = '') return
                    <p>Please select an image from the drop-down list above or add a new one.</p>
                
                default return
                    <img id="img" src="{$cfdb-relpath}/data/tablets/{$tablet-id}/{$surface-id}"/>
        }</div>
        
        {if ($tablet-id != '')
        then <div id="preview"/>
        else ()}
    </body>
</html>