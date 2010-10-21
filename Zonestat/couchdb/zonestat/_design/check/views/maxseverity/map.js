function(doc){
    var value = {
        "CRITICAL": 5,
        "ERROR": 4,
        "WARNING": 3,
        "NOTICE": 2,
        "INFO": 1,
        "DEBUG": 0
        };
    
    var max = "DEBUG";
    
    if(doc.dnscheck) {
        for(i in doc.dnscheck) {
            if(value[doc.dnscheck[i].level] > value[max]) {
                max = doc.dnscheck[i].level;
            }
        }
    }
    
    emit(max, 1);
}