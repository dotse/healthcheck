$(document).ready(function(){
    $("dd").hide();
    $("dt").append("<a href='#' class='toggle'>[show]</a>");
    $("a.toggle").click(function(e){
        $(this).parents("dt").next("dd").toggle();
        switch ($(this).text()) {
            case '[show]':
                $(this).text("[hide]");
                break;
            case '[hide]':
                $(this).text("[show]");
                break;
        }
        e.preventDefault();
    })
 });