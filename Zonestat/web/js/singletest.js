$(document).ready(function(){
   $("tr.info").hide();
   $("h1").after('<b>Toggle visibility:</b> <a href="#" class="error_toggle">Error</a> <a href="#" class="warning_toggle">Warning</a> <a href="#" class="notice_toggle">Notice</a> <a href="#" class="info_toggle">Info</a>');
   $("a.error_toggle").click(function(){
      $("tr.error").toggle();
   });
   $("a.warning_toggle").click(function(){
      $("tr.warning").toggle();
   });
   $("a.notice_toggle").click(function(){
      $("tr.notice").toggle();
   });
   $("a.info_toggle").click(function(){
      $("tr.info").toggle();
   });
});