function(doc){
    for(n in doc.mailservers) {
        if (doc.mailservers[n].ip.indexOf(':') >= 0) {
            emit(doc.domain, doc.mailservers[n].ip);
        };
    }
}