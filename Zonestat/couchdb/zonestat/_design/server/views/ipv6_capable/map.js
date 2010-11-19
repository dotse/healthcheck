function(doc){
    var v6 = null;
    
    if(doc.geoip){
        for each (e in doc.geoip){
            if(e.ipversion == "6") {
                v6 = true;
            }
            if (v6 == null && e.ipversion == "4") {
                v6 = false;
            }
        }
        if(v6 == null) {
            return;
        } else if(v6) {
            emit(doc.testrun, 1);
        } else {
            emit(doc.testrun, 0);
        }
    }
}