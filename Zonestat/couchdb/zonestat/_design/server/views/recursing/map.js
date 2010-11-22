function(doc){
    var recursing = 0;
    
    if(doc.dnscheck){
        for each (e in doc.dnscheck){
            if (e.tag == "NAMESERVER:RECURSIVE") {
                recursing = 1;
            }
        }
        emit(doc.testrun, [recursing, 1]);
    }
}