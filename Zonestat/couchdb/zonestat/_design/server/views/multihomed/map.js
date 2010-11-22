function(doc){
    var v4multihomed = 0;
    var v6multihomed = 0;
    
    if(doc.dnscheck){
        for each (e in doc.dnscheck){
            if(e.tag == "CONNECTIVITY:ASN_COUNT_OK") {
                v4multihomed = true;
            } else if(e.tag == "CONNECTIVITY:V6_ASN_COUNT_OK") {
                v6multihomed = true;
            }
        }
        
        emit(doc.testrun, [v6multihomed, v4multihomed, 1]);
    }
}