function(doc){
    if(doc.dnscheck) {
        for(i in doc.dnscheck) {
            emit([doc.dnscheck[i].level, doc.dnscheck[i].tag], 1);
        }
    }
}