var cfdb = cfdb || {};
cfdb.signlist = {};

var submitTimeout;
var defaultTimeout = 700;
cfdb.dateRange = {};
cfdb.dateRange.max = 0;
cfdb.dateRange.min = -800;

$(document).ready(function(){
    // select sign and autoload
    $('select[name = s]').on("change",function(e){
        if (submitTimeout) {
            clearTimeout(submitTimeout);
        }
        submitTimeout = setTimeout(cfdb.signlist.submitnavform, defaultTimeout);
    });
    
    // remove filter and autoload 
    $("#signlist-nav-form").on("click", ".label a", function(e){
        var filter = $(this).attr("data-filter");
        $( "#" + filter + "-display").addClass("hidden");
        $("#" + filter + "-input").val("");
        var sliderVals = $( "#slider-range" ).slider("values"); 
        if (filter == "after") {
            $( "#slider-range" ).slider("values", [cfdb.dateRange.min, sliderVals[1]]);
        } else {
            $( "#slider-range" ).slider("values", [sliderVals[0], cfdb.dateRange.max]);
        }
        if (submitTimeout) {
            clearTimeout(submitTimeout);
        }
        submitTimeout = setTimeout(cfdb.signlist.submitnavform, defaultTimeout);
    });
    
    //pagination links set the values of the "s" input and submit the form
    $("#signlist-nav-form").on("click", ".pagination a", function(e){
        $(e).preventDefault();
        var s = $(this).attr("data-s");
        $("select[name = s]").val(s);
        $("#signlist-nav-form").submit();
    });
    
    
    $( "#slider-range" ).slider({
      range: true,
      max: cfdb.dateRange.max,
      min: cfdb.dateRange.min,
      create: function( event, ui ) {
        // shortcuts to labels that display maximum and minimum of the range slider
        // and currently selected values
        var labelMax = $("#slider-range-max"),
            labelMin = $("#slider-range-min"),
            labelBefore = $( "#before-display .content" ),
            labelAfter = $( "#after-display .content" );
        // variables "before" and "after" contain either rrequest parameter values 
        // (passed via hidden input fields from the server side)
        // or default to minimum / maximum values.  
        var before = $("#before-input").val() != "" ? $("#before-input").val() : cfdb.dateRange.max;
        var after = $("#after-input").val() != "" ? $("#after-input").val() : cfdb.dateRange.min;
         // set the initial slider values
        $(this).slider("values", [after, before]);
        
        
        // set values of minimum and maximum labels  
        labelMax.html(cfdb.dateRange.max.toString().replace("-","") + " BC");
        labelMin.html(cfdb.dateRange.min.toString().replace("-","") + " BC");
        
        /* if selected lower and upper limits are the same as the range minimum and maximum 
           hide the labels, otherwise show them and update the label text. */
        if (before == cfdb.dateRange.max) {
            labelBefore.parent().addClass("hidden"); 
        } else  {
            labelBefore.parent().removeClass("hidden");
            labelBefore.html("before " + before.toString().replace("-","") + " BC" );
        }
        if (after == cfdb.dateRange.min) {
            labelAfter.parent().addClass("hidden"); 
        } else  {
            labelAfter.parent().removeClass("hidden");
            labelAfter.html( "after " + after.toString().replace("-","") + " BC" );
        }
      },
      slide: function( event, ui ) {
        var before = ui.values[ 1 ],
            after = ui.values[ 0 ];
        if (before == cfdb.dateRange.max) {
            $( "#before-display .content" ).parent().addClass("hidden"); 
        } else  {
            $( "#before-display .content" ).parent().removeClass("hidden");
        }
        
        
        if (after == cfdb.dateRange.min) {
            $( "#after-display .content" ).parent().addClass("hidden"); 
        } else  {
            $( "#after-display .content" ).parent().removeClass("hidden");
        }
        $( "#before-display .content" ).html( "before " + before.toString().replace("-","") + " BC");
        $( "#after-display .content" ).html( "after " + after.toString().replace("-","") + " BC");
        $("#before-input").val(before);
        $("#after-input").val(after);
        if (submitTimeout) {
            clearTimeout(submitTimeout);
        }
        submitTimeout = setTimeout(cfdb.signlist.submitnavform, defaultTimeout);
      }
    });
});

cfdb.signlist.submitnavform = function() {
    $('#signlist-nav-form').submit();
};