/*var cfdb = {};*/

cfdb.settings = {};

/* generic object for methods of one or all annotations on one surface */
cfdb.annotation = {};
cfdb.annotations = {};
cfdb.taxonomies = {};

cfdb.url = "/exist/restxq/cfdb/";

cfdb.taxonomies.url = cfdb.url + "taxonomies/";

/*cfdb.tablet = {};
cfdb.surface = {};*/

cfdb.signs = [];


cfdb.loadSurfaces = function () {
    "use strict";
    var dom = $('#sel-surface'),
        url = cfdb.url + "tablets/" + cfdb.tablet + "/surfaces",
        settings = {
            url: url,
            contentType: 'application/json',
            method: 'GET'
        };
    $.ajax(settings).success( function ( response ) {
        dom.empty();
        $(response.surface).each(function( index, item ) {
            $('<option value=' + item.id +'>' + item.name + '</option>').appendTo(dom);
        });
    });
};



cfdb.loadSigns = function (selectedValue) {
    "use strict";
    var url = cfdb.taxonomies.url + "signs",
        settings = {
            url: url,
            contentType: 'application/json',
            method: 'GET'
        };
    return $.ajax(settings).success( function ( response ) {
        cfdb.signs = response.sign;
        $('#sign').empty();
        var i;
        for (i = 0; i < cfdb.signs.length; i += 1) {
            $('#sign').append('<option value="' + cfdb.signs[i].name + '">' + cfdb.signs[i].name + "</option>")
        }
        $('#sign').append('<option value="" disabled="disabled">[n/a]</option>');
        selectedValue !== "" && $('#sign').val(selectedValue);
    })
};

/* creates a new server-side annotation, retrieves the uuid of the new annotation 
   and creates a thumbnail view of it in the signs list */
cfdb.annotation.create = function (tabletID, surfaceID, params) {
    "use strict";
    var url = cfdb.url + "tablets/" + tabletID + "/surfaces/" + surfaceID,
        load = cfdb.prepareJSON(params),
        settings = {
            url: url,
            dataType: 'json',
            contentType: 'application/json',
            method: 'POST',
            data: load
        };
    return $.ajax(settings).success(function (response) {
        params.uuid = response.uuid;
        cfdb.renderThumbnail(params, $('#list'));
    })
};

/* updates one annotation */
cfdb.annotation.set = function (tabletID, surfaceID, params) {
    var url = cfdb.url + "tablets/" + tabletID + "/surfaces/" + surfaceID + "/annotations/" + params.uuid,
        load = cfdb.prepareJSON(params),
        settings = {
            url: url,
            dataType: 'json',
            contentType: 'application/json',
            method: 'PUT',
            data: load
        };
    return $.ajax(settings).success(function () {
        cfdb.annotations.list($('#list'), cfdb.tablet, cfdb.surface.id);
    })
};

cfdb.annotation.remove = function (tabletID, surfaceID, annotationID, params) {
    console.log("cfdb.annotation.remove " + tabletID + ", " + surfaceID + ", " + annotationID);
    var url = cfdb.url + "tablets/" + tabletID + "/surfaces/" + surfaceID + "/annotations/" + annotationID,
        settings = {
            url: url,
            contentType: 'application/json',
            method: 'DELETE',
            success: function (response) {
                cfdb.annotations.list($('#list'), tabletID, surfaceID);
            },
            error: function (response) {
                console.log(response);
            }
        };
    return $.ajax(settings);
};

/* retrieves all annotations from the server for a given */
/* element: the element to append the annotation DOM elements to */
cfdb.annotations.list = function (parentElt, tabletID, surfaceID, filterExpr) {
    var url = cfdb.url + "tablets/" + tabletID + "/surfaces/" + surfaceID + "/annotations",
        settings = {
            url: url,
            dataType: 'json',
            contentType: 'application/json',
            method: 'GET'
        };
    if (filterExpr !== undefined && filterExpr !== "") {
        settings.data = "filter=" + filterExpr;
    }
    $.ajax(settings).success(function (response) {
        $('#list').empty();
        var no;
        if (response !== null) {
            no = typeof response.annotation.length === "number" ? response.annotation.length : 1;
        } else {
            no = 0
        }
        if (no === 1) {
            cfdb.renderThumbnail(response.annotation,parentElt);
        } else {
            var i;
            for (i = 0; i < no; i += 1) {
                cfdb.renderThumbnail(response.annotation[i],parentElt);
            }
        }
    });
};

cfdb.setData = function (node, data) {
    node.data(data);
};

cfdb.prepareJSON = function (data) {
    var strings = [],
        k;

    /* loop over object keys and push to strings array
    if value is not a number, put inside quotes */
    for (k in data) {
        if (data.hasOwnProperty(k) ) {
            strings.push("\"" + k + "\":" + ( typeof data[k] !== "number" ? "\"" : "" ) + data[k] + ( typeof data[k] !== "number" ? "\"" : "" ) )   
        }
    }
    var json = "{" + strings.join() + "}";
    /*if (JSON.stringify(JSON.parse(json)) === JSON.stringify(data)) {*/
        return json
    /*} else {
        console.log("json serialization and object do not match");
        console.log(data);
        console.log(json);
        return false
    }*/
};

cfdb.storeAnnotation = function (node) {
    var json = cfdb.prepareJSON(node);
    console.log(json);
};

cfdb.initCropper = function (node) {
    $(node).cropper({
        guides: false,
        highlight: true,
        movable: true,
        resizable: true,
        background: false,
        autoCropArea: 0.18,
        preview: "#preview",
        built: function () {
            $("<button id='btn-crop'>annotate</button>").prependTo('.cropper-cropbox')
        },
        dragstart: function () {
            $('#detailsContent').empty();
            $('#details').hide();
        },
        dragend: function () {
            $('#btn-crop').show();
        }
    });
};

cfdb.zoomIn = function (node) {
    $(node).cropper("zoom", 0.4);
};

cfdb.zoomOut = function (node) {
    $(node).cropper("zoom", -0.4);
};

cfdb.renderThumbnail = function (props, parentElt) {
    var t = "<div class='thumbnail' data-uuid='" + props["uuid"] + "'>"
                + "<img src='" + props["img"] + "'/>"
                + cfdb.renderProps(props)
                + "<span class='annotationMenu'>"
                    + "<a href='#' class='annotationInfo fa fa-info' title='display annotation details'/>"
                    + "<a href='#' class='annotationEdit fa  fa-pencil' title='edit annotation details'/>"
                    + "<a href='#' class='annotationRemove fa fa-times' title='remove sign'/>"
                + "</span>"
            + "</div>";
    var node = $(t);
    cfdb.setData(node, props);
    node.appendTo(parentElt);
};

cfdb.renderProps = function (props) {
    var trs = "";
    var ignored = ["img", "tablet", "surface"];
    var techProps = ["x", "y", "width", "height", "rotate", "uuid"];
    var k;
    //var cb = "<tr><td/><td><input type='checkbox' id='annotationShowTech'>show technical details</input></td></tr>"
    for (k in props) {
        var cat = techProps.indexOf(k) === -1 ? "'ann'" : "'tech'";
        if (ignored.indexOf(k) === -1) {
            trs += "<tr data-category=" + cat + "><td>" + k + "</td><td>" + props[k] + "</td></tr>";
        }
    }
    return "<table class='props'><tbody>" + trs + "</tbody></table>"
};

cfdb.prepareAnnotationEditDialog = function (data) {
    /* fill signs selectbox */
    var fields= $('#dialog-edit fieldset').find("input, select, textarea"),
        i;
    for (i = 0; i < fields.length; i += 1) {
        var field = fields[i],
            name = $(field).attr("name"),
            value = data[name];
        if (value !== "") {
            field.type === "select-one" ? $(field).find("option[value=" + value + "]").prop("selected", true) :$(field).val(value); 
        }
    }
};


cfdb.details = {};

cfdb.details.refresh = function ($props) {
    $detailsContent = $('#detailsContent');
    $detailsContent.empty();
    $props.clone().appendTo($detailsContent);        
};


cfdb.surface.remove = function() {
    settings = {
        url: cfdb.url + 'tablets/' + cfdb.tablet + '/surfaces/' + cfdb.surface.id,
        method: 'DELETE'
    };
    return $.ajax(settings).success(function (response) {
        console.log(response);
    })
};



 
cfdb.attachFileAttributes = function (uploader, files) {
    console.log("cfdb.attachFileAttributes");
    for (var i = 0; i < files.length; i++) {
        var file = files[i];
        preloader = new mOxie.Image();
        preloader.onload = function () {
            var param = {
                width: preloader.width,
                height: preloader.height,
                type: preloader.type,
                filename: preloader.name
            };
            uploader.setOption("multipart_params", param);
            uploader.start();
        }
        preloader.load( file.getSource() );
    }
};

$(document).ready(function () {
    var $img = $('#img'),
        tmpImg = new Image();
    tmpImg.src = $img.attr("src");
    cfdb.surface.width = tmpImg.width;
    cfdb.surface.height = tmpImg.height;
    
    cfdb.initCropper($img);
    var $list = $('#list');
    
    /* list present annotations */
    cfdb.annotations.list($list, cfdb.tablet,cfdb.surface.id);
    
    $('#preview').draggable();
    $('#details').draggable();
    
    $('#zoomin').click(function (e) {
        e.preventDefault();
        cfdb.zoomIn($img);                
    });
    
    $('#zoomout').click(function (e) {
        e.preventDefault();
        cfdb.zoomOut($img);                
    });
    
     $( "#slider-thumbnailHeight" ).slider({
        range: "min",
        value: 90,
        min: 30,
        max: 400,
        slide: function( event, ui ) {
            $( ".thumbnail img" ).css("height", ui.value + "px");
        }
    });
    
    $('#filterList a').click(function (e) {
        e.preventDefault();
        var filterExpr = $(this).parent().find("input[name = 'filter']").val();
        var $list = $('#list');
        cfdb.annotations.list($list, cfdb.tablet,cfdb.surface.id, filterExpr);
    });
    
    $('#list').sortable({
        stop: function(event, ui) {
            var k, data = {}; 
            for (k in ui.item.data()) {
                data[k] = $(ui.item).data()[k];
            }
            data.n = ui.item.index();
            ui.item.data(data);
        }
    });
    
    /* create annotation */
    $('#main').on('click', '#btn-crop', function () {
        var geometry = $img.cropper("getData");
        var params = {};
        var g;
        for (g in geometry) {params[g] = geometry[g]}
        params.img = $img.cropper("getDataURL");
        cfdb.annotation.create(cfdb.tablet, cfdb.surface.id, params);
        $('#btn-crop').hide();
    });
    
    /* show crop box on main image when clicking on thumbnail */
    $('#list').on('mouseenter mouseleave', '.thumbnail', function (e) {
        var data = $( this ).data();
        /*  set the box left / right, according to the zoomfactor  */
        var imgdata = $('#img').cropper("getImageData",true); 
        var zoomfactor = imgdata.width / imgdata.naturalWidth;
        var left = parseInt(data["x"]) * zoomfactor + imgdata.left;
        var top = parseInt(data["y"]) * zoomfactor + imgdata.top;
        var height = parseInt(data["height"]) * zoomfactor;
        var width = parseInt(data["width"]) * zoomfactor;
    
        var cropBoxData = {
            left:  left,
            top: top,
            width: width,
            height: height
        };
        $('#img').cropper("setCropBoxData", cropBoxData);
        cfdb.details.refresh($(this).find(".props"));
    });
    
    
    $('#list').on('click', '.annotationInfo', function (e) {
        var $details = $('#details');
        if ($details.filter(":hidden").length > 0) {
            var $props = $(e.target).parents(".thumbnail").children(".props")
            cfdb.details.refresh($props);
            $details.show();
        } else {
            $details.hide();
        }
    });
    
    
    /* creating jq UI dialog for all removal operations */
    $( "#dialog-confirmAnnotationRemove" ).dialog({
            resizable: true,
            modal: true,
            autoOpen: false,
            title: 'Delete Annotation',
            buttons: {
                "Yes, delete": function () {
                    var thumbnail = $('.thumbnail[data-uuid="' + cfdb.currentSign + '"]');
                    cfdb.annotation.remove(cfdb.tablet, cfdb.surface.id, cfdb.currentSign);
                    $('#detailsContent').empty();
                    $('#details').hide();
                    $( this ).dialog( "close" );
            },
            Cancel: function () {
              $( this ).dialog( "close" );
              cfdb.currentSign = "";
            }
          }
    });
    
    /* creating jq UI dialog for all removal operations */
    $("#dialog-confirmSurfaceRemove").dialog({
            resizable: true,
            modal: true,
            autoOpen: false,
            title: 'Delete Surface',
            buttons: {
                "Yes, delete": function () {
                    /* remove surface via ajax call */
                    cfdb.surface.remove();
                    $( this ).dialog( "close" );
                    /* reload page */
/*                    $('#fm-surface').submit();*/
            },
            Cancel: function () {
              $( this ).dialog( "close" );
            }
          }
    });
    
    /* create annotation edit dialog */
    $('#dialog-edit').dialog({
        modal: true,
        autoOpen: false,
        title: 'Edit Annotation',
        width: 400,
        buttons: {
            "Save": function () {
                var data = $(this).find("form").serializeArray(),
                    params = {},
                    i;
                for (i = 0; i < data.length; i += 1) {
                    params[data[i].name] = data[i].value;
                }
                cfdb.annotation.set(cfdb.tablet, cfdb.surface.id, params);
                $( this ).dialog("close");
            },
            Cancel: function () {
              $( this ).dialog( "close" );
              cfdb.currentSign = "";
            }
        }
    });
    
    $('#menu').on('change', '#sel-surface', function (e) {
        $(e.target).parents("form").submit();
    }); 
    
    /* show annotation edit dialog on click, copy thumbnail.data() to the form inputs */ 
    $('#list').on('click', '.annotationEdit', function ( event ) {
        var data = $(event.target).parents(".thumbnail").data();
        // value of the option to select is passed to loadSigns 
        cfdb.loadSigns(data.sign);
        cfdb.prepareAnnotationEditDialog(data);
        $("#dialog-edit").dialog("open");
    });
    
    
    /* delete annotation dialog */
    $('#list').on('click', '.annotationRemove', function (e) {
        cfdb.currentSign = $(e.target).parents('.thumbnail').data().uuid;
        $( "#dialog-confirmAnnotationRemove" ).dialog( "open");
    });
    
    
/*    cfdb.loadSurfaces();*/
     
    
    $('#uploader').plupload({
        url: cfdb.url + 'tablets/' + cfdb.tablet + '/surfaces',
        filters : [
          {title : "Image files", extensions : "jpg,png"}
        ],
        init: {
            FilesAdded: function(up, files) {cfdb.attachFileAttributes(up, files);}
            /*BeforeUpload: function(up, files) {cfdb.setRequestParams(up, files); console.log(up.settings);}*/
        },
        complete : function(up, files) {cfdb.loadSurfaces();},
        error : function(code, msg) {console.log(code,msg);$('#uploader').plupload("notify", "error", msg);},
        rename: false,
        sortable: false,
        unique_names: true,
        autostart: false,
        multipart: false
      });
      
      
      $('#uploader').dialog({
          autoOpen: false,
          modal: true,
          width: 800
      });
      
      $('#addSurface').click(function(e){
        e.preventDefault();
        $('#uploader').dialog("open");
      });
      
      $('#removeSurface').click(function(e){
        e.preventDefault();
        $("#dialog-confirmSurfaceRemove").dialog("open");
      });
});



