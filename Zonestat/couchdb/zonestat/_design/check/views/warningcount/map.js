function(doc){
    if(doc.dnscheck) {
        for(i in doc.dnscheck) {
            if(doc.dnscheck[i].level == 'WARNING') {
                emit(doc.dnscheck[i].tag, 1);
            }
        }
    }
}