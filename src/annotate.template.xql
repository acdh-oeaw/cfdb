xquery version "3.0";
import module namespace tablet = "@app.uri@/tablet" at "modules/tablet.xqm";
import module namespace surface = "@app.uri@/surface" at "modules/surface.xqm";
import module namespace config = "@app.uri@/config" at "modules/config.xqm";

declare namespace tei = "http://www.tei-c.org/ns/1.0";

declare namespace output = "http://www.w3.org/2010/xslt-xquery-serialization";
declare option output:method "html";
declare option output:media-type "text/html";

let $cfdb-relpath := "../@app.name@",
    $tablets := tablet:list()

(:let $user := request:get-attribute($config:domain||".user"),:)
let $user := session:get-attribute("user"),
    $pwd := session:get-attribute("password")

let $tablet-id := request:get-parameter("t", ""),
    $tablet := if ($tablet-id = '') then () else tablet:get($tablet-id),
    $tablet-title := $tablet//tei:title/xs:string(.),
    $tablet-col := if ($tablet-id = '' or not(exists($tablet))) then () else util:collection-name($tablet),
    $tablet-doc := if ($tablet-id = '' or not(exists($tablet))) then () else util:document-name($tablet),
    $tablet-owner := if ($tablet-id = '' or not(exists($tablet))) then () else xmldb:get-owner($tablet-col, $tablet-doc),
    $tablet-writeable := if ($user = $config:editors) 
                         then true()
                         else 
                            if ($user = $tablet-owner)
                            then true()
                            else false(),
    $annotation-id := request:get-parameter("a", ""),
    $surfaces := if ($tablet-id = '' or not(exists($tablet))) then () else tablet:listSurfaces($tablet),
    $surface-id := request:get-parameter("s", $surfaces[1]/tei:graphic[1]/xs:string(@url)),
    $surface-available := 
        switch (true())
            case $tablet-id = '' return (util:log-app("DEBUG", "cfdb", "tablet-id=''"), false())
            case (not($tablet)) return (util:log-app("DEBUG", "cfdb", "not($tablet)"), false())
            case ($surface-id = '') return (util:log-app("DEBUG", "cfdb", "$surface-id = ''"), false())
            case (not($surface-id)) return (util:log-app("DEBUG", "cfdb", "not($surface-id)"), false())
            default return surface:exists($tablet, $surface-id)
let $filter := request:get-parameter("filter", $annotation-id)
let $js := "var cfdb = {}; cfdb.surface = {}; cfdb.user = '"||$user||"'; cfdb.password = '"||$pwd||"'; cfdb.writable = '"||$tablet-writeable||"'; cfdb.tablet = '"||$tablet-id||"';&#10;cfdb.surface.id = '"||$surface-id||"';&#10;cfdb.surfaces = ["||string-join(for $s in $surfaces return concat("'",$s/tei:graphic/@url,"'"), ",")||"]; cfdb.a = '"||$annotation-id||"'; "
return


<html xmlns="http://www.w3.org/1999/xhtml">
    <head>
        <title>Tablet Annotator</title>
        <script src="resources/js/jquery-2.1.3.min.js" type="text/javascript">//</script>
        <script src="resources/js/jquery-ui-1.11.3/jquery-ui.min.js" type="text/javascript">//</script>
        <link href="resources/js/jquery-ui-1.11.3/jquery-ui.min.css" rel="stylesheet"/>
        
        <!-- disable caching-->
        <meta http-equiv="cache-control" content="max-age=0"/>
        <meta http-equiv="cache-control" content="no-cache"/>
        <meta http-equiv="expires" content="0"/>
        <meta http-equiv="expires" content="Tue, 01 Jan 1980 1:00:00 GMT"/>
        <meta http-equiv="pragma" content="no-cache"/>
        
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
            <script type="text/javascript" src="resources/js/common.js">//</script>,
            <script type="text/javascript" src="resources/js/annotate.js">//</script>,
            if ($annotation-id != '')
            then ()
                (:<script type="text/javascript"><![CDATA[
                    // highlight crop area, if there is an "a" request parameter
                    $(document).ready(function(){
                        if (cfdb.a !== '') {
                            var $div = $('#list div[data-uuid="' + cfdb.a + '"]');
                            console.log($div);
                            // trigger mouseenter event on the sign in sign list 
                            $div.mouseenter();
                        }
                    }
                );]]></script>:)
            else ()
            )
        else ()}
    </head>
    <body>
        {
        if (not(exists($surface-id)))
        then ()
        else
        if ($tablet-id ='') 
        then ()
        else 
            if (not($surface-available))
            then ()
            else
               (
               <div id="menu">
                   <form id="fm-surface">
                       <span class="currentUser">current user: {$user}</span>
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
                   {if ($tablet-writeable)
                   then <a href="editTablets.html?t={$tablet-title}" id="editTablet" class="menuitem"><span class="fa fa-pencil"></span>&#160;edit this tablet</a> 
                   else <a href="editTablets.html?t={$tablet-title}&amp;m=show" id="editTablet" class="menuitem"><span class="fa fa-pencil"></span>&#160;show this tablet</a>}
                   <span id="zoomControlsContainer">
                       <a href="#" id="zoomin" class="menuitem"><span class="fa fa-search-plus"></span></a>
                       <a href="#" id="zoomout" class="menuitem"><span class="fa fa-search-minus"></span></a>
                   </span>
                   <div id="uploader">
                       <div id="filelist">Your browser doesn't have Flash, Silverlight or HTML5 support.</div>
                       <br />
                        
                       <div id="container">
                           <a id="pickfiles" href="javascript:;">[Select files]</a>
                           <!--<a id="uploadfiles" href="javascript:;">[Upload files]</a>:)-->
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
               
               (: dialog for restxq endpoint token authorization - needs to be tested :) 
               (:<div id="dialog-login" title="Login">
                    <form action="" method="post">
                        <label>User name:</label>
                        <input id="name" name="name" type="text"/>
                        <label>Password:</label>
                        <input id="pwd" name="password" type="password"/>
                        <input id="submit" type="submit" value="Submit"/>
                    </form>
               </div>,:)
               
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
                       <input name="filter" placeholder="filter by annotation content" title="filter by annotation content" value="{$filter}"/>
                       <!-- moved to keydown trigger -->
                       <!--<a href="#" class="fa fa-search" id="applyFilter">&#160;</a>-->
                       <a href="#" class="fa fa-remove" id="emptyFilter">&#160;</a>
                       <div id="slider-thumbnailHeight" title="set thumbnail size">
                           <!-- slider for setting thumbnail height -->
                       </div>
                   </form> 
                   <div id="list">
                       <!-- container for ajax loaded sign list -->
                   </div>
               </div>)
        }
        
        <div id="main">{
            switch(true())
                case (not(exists($tablets))) return
                    <div id="noSurfaceDialog">
                        <p>No tablets found in database. <a href="editTablets.html">Create one now.</a></p>
                    </div>
                    
                case ($tablet-id = '' or not(exists($tablet))) return
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
                    
                case (not(exists($surface-id))) return 
                    <div id="noSurfaceDialog">
                        <p>No image for this tablet in the database yet. <br/>You may want to <a href="#" id="addSurface">upload an image</a> now or <a href="editTablets.html?t={fn:encode-for-uri($tablet-title)}{if(not($tablet-writeable)) then '&amp;m=show' else ()}">{if(not($tablet-writeable)) then 'view' else 'edit'} the table metadata.</a></p>
                        <div id="uploader">
                            <div id="filelist">Your browser doesn't have Flash, Silverlight or HTML5 support.</div>
                            <br />
                             
                            <div id="container">
                                <a id="pickfiles" href="javascript:;">[Select files]</a>
                            </div>
                             
                            <br />
                            <pre id="console"></pre>
                        </div>
                     </div>
                
                case ($surface-id = '') return
                     <div id="noSurfaceDialog">
                        <p>Please select an image from the drop-down list above or add a new one.</p>
                     </div>
                
                case (not($surface-available)) return
                    <div id="noSurfaceDialog">
                        <p>Surface not available. <a href="?t={$tablet-id}">Return to tablet.</a></p>
                    </div>
                
                default return
                    <img id="img" src="/exist/apps/{$config:app-name}/$app-root/data/tablets/{$tablet-id}/{$surface-id}"/>
        }</div>
        
        {if ($tablet-id != '' and $surface-id!='' and $surface-available)
        then <div id="preview"/>
        else ()}
    </body>
</html>