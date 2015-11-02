var cfdb = cfdb || {};
cfdb.signlist = {};

var submitTimeout;

$(document).ready(function(){
    $('select[name = s]').on("change",function(e){
        if (submitTimeout) {
            clearTimeout(submitTimeout);
        }
        submitTimeout = setTimeout(cfdb.signlist.submitnavform, 1000);
    });
    
    $( "#slider-range" ).slider({
      range: true,
      max: 0,
      min: 1000,
      values: [ 75, 300 ]
    });
});

cfdb.signlist.submitnavform = function() {
    $('#signlist-nav-form').submit();
};