function(doc){
    var dnssec = 0;
    
    if(doc.dnscheck){
        for each (e in doc.dnscheck){
            if (e.tag == "DNSSEC:DS_FOUND") {
                dnssec = 1;
            }
        }
        emit(doc.testrun, [dnssec, 1]);
    }
}