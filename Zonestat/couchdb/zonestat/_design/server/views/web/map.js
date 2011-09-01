function(doc){
    if (doc.webinfo.http && doc.webinfo.https) {
        emit(doc.testrun, {http:1, https:1});
    } else if (doc.webinfo.http) {
        emit(doc.testrun, {http:1, https:0});
    } else if (doc.webinfo.https) {
        emit(doc.testrun, {http:0, https:1});
    } else {
        emit(doc.testrun, {http:0, https:0});
    }
}