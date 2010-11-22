function(doc){
    var starttls = 0;
    
    if(doc.mailservers) {
        for each (e in doc.mailservers) {
            if(e.starttls) {
                starttls = 1;
                break;
            }
        }
        emit(doc.testrun, [starttls, 1]);
    }
}