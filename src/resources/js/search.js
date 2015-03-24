var cfdb = cfdb || {};
cfdb.search = {};

$(document).ready(function(){
    /* add Input field on click on "addInput" link */
    $('#searchForm').on("click", ".addInput", function(e){
        var elt = $(e.target),
            fs = elt.parents("fieldset").first(),
            clone = fs.clone();
            name = fs.attr("name"), 
            // find similar input fields
            cnt = fs.parent().find("fieldset[name=" + name + "]").length,
            last = fs.parent().find("fieldset[name=" + name + "]").last(),
            // show the "remove field" button on the last input before appending the new one
            last.find(".rmInput").show();
        // append the copied input field
        fs.after(clone);
        clone.find("input,select,textarea").val("").focus();
        fss = fs.parent().find("fieldset[name=" + name + "]"),
        cnt = fss.length;
        cnt === 2 && fss.find(".rmInput").show();
    });
    
    $('#searchForm').on("click", ".rmInput", function(e){
        var elt = $(e.target),
            fs = elt.parents("fieldset").first(),
            name = fs.attr("name"),
            // find similar input fields
            fss = fs.parent().find("fieldset[name=" + name + "]"),
            cnt = fss.length;
       // remove the input field only if it's not the last one
       // and hide the "remove field" button on it
       if (cnt >= 2) {
            fs.remove();
            cnt === 2 && fss.find(".rmInput").hide();
       }
    });
    
    $('#clearSignSelection').click(function(e){
        var elt = $(e.target),
            fs = elt.parents("fieldset").first();
        fs.find("option:selected").attr("selected", false);
    });
}); 