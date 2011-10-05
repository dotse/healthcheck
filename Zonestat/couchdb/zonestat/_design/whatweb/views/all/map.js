function(doc){
    if(doc.whatweb && doc.whatweb.length > 0) {
        emit([doc.testrun, doc.domain], doc.whatweb);
    }
}