function(doc){
    if (doc.webinfo.http && doc.webinfo.https) {
        emit(doc.testrun, [1,1]);
    } else if (doc.webinfo.http) {
        emit(doc.testrun, [1,0]);
    } else if (doc.webinfo.https) {
        emit(doc.testrun, [0,1]);
    } else {
        emit(doc.testrun, [0,0]);
    }
}