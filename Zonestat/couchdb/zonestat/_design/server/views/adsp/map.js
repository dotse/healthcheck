function(doc){
    if(doc.dkim) {
        if(doc.dkim.adsp) {
            emit(doc.testrun, [1,1]);
        } else {
            emit(doc.testrun, [0,1]);
        }
    }
}