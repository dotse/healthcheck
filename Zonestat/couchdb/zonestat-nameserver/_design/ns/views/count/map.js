function(doc){
    emit([doc.testrun, doc.ipversion, doc.address], 1);
}