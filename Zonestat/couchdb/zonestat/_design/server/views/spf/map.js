function(doc){
    if(doc.dkim) {
        if(doc.dkim.spf_real || doc.dkim.spf_transitionary) {
            emit(doc.testrun, [1,1]);
        } else {
            emit(doc.testrun, [0,1]);
        }
    }
}