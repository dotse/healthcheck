function(doc){
    if(doc.failed){
        emit(doc.testrun, doc.domain);
    }
}